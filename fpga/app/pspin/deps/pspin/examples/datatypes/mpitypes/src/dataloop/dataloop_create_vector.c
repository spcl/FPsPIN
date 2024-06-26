/* -*- Mode: C; c-basic-offset:4 ; -*- */

/*
 *  (C) 2001 by Argonne National Laboratory.
 *      See COPYRIGHT in top-level directory.
 */

#include "./dataloop.h"

#include <stdio.h>

/*@
   Dataloop_create_vector

   Arguments:
+  int icount
.  int iblocklength
.  MPI_Aint astride
.  int strideinbytes
.  MPI_Datatype oldtype
.  DLOOP_Dataloop **dlp_p
.  int *dlsz_p
.  int *dldepth_p
-  int flag

   Returns 0 on success, -1 on failure.

@*/
int PREPEND_PREFIX(Dataloop_create_vector)(int icount,
					   int iblocklength,
					   MPI_Aint astride,
					   int strideinbytes,
					   DLOOP_Type oldtype,
					   DLOOP_Dataloop **dlp_p,
					   int *dlsz_p,
					   int *dldepth_p,
					   int flag)
{
    int err, is_builtin;
    int new_loop_sz, new_loop_depth;

    DLOOP_Count count, blocklength;
    DLOOP_Offset stride;
    DLOOP_Dataloop *new_dlp;

    count       = (DLOOP_Count) icount; /* avoid subsequent casting */
    blocklength = (DLOOP_Count) iblocklength;
    stride      = (DLOOP_Offset) astride;

    /* if count or blocklength are zero, handle with contig code,
     * call it a int
     */
    if (count == 0 || blocklength == 0)
    {

	err = PREPEND_PREFIX(Dataloop_create_contiguous)(0,
							 MPI_INT,
							 dlp_p,
							 dlsz_p,
							 dldepth_p,
							 flag);
	return err;
    }

    /* optimization:
     *
     * if count == 1, store as a contiguous rather than a vector dataloop.
     */
    if (count == 1) {
	err = PREPEND_PREFIX(Dataloop_create_contiguous)(iblocklength,
							 oldtype,
							 dlp_p,
							 dlsz_p,
							 dldepth_p,
							 flag);
	return err;
    }

  

    
    if (stride == 0) {

    }

    is_builtin = (DLOOP_Handle_hasloop_macro(oldtype)) ? 0 : 1;

    {
    	// ktaranov optimization
 		
    	//DLOOP_Offset c_sz = 0;
    	DLOOP_Offset old_extent = 0;
		//DLOOP_Handle_get_size_macro(oldtype, c_sz);
		DLOOP_Handle_get_extent_macro(oldtype, old_extent);
		printf("extend %ld \n",old_extent);

   		if( ( strideinbytes ?  iblocklength*old_extent : iblocklength ) ==  stride  ){
    	printf("ktaranov: Optimization when vec with stride == block\n");
		err = PREPEND_PREFIX(Dataloop_create_contiguous)(count*blocklength,
							 oldtype,
							 dlp_p,
							 dlsz_p,
							 dldepth_p,
							 flag);
			return err;
		}
	     
	}

    if (is_builtin) {
	new_loop_sz = sizeof(DLOOP_Dataloop);
	new_loop_depth = 1;
    }
    else {
	int old_loop_sz = 0, old_loop_depth = 0;

	DLOOP_Handle_get_loopsize_macro(oldtype, old_loop_sz, flag);
	DLOOP_Handle_get_loopdepth_macro(oldtype, old_loop_depth, flag);

	/* TODO: ACCOUNT FOR PADDING IN LOOP_SZ HERE */
	new_loop_sz = sizeof(DLOOP_Dataloop) + old_loop_sz;
	new_loop_depth = old_loop_depth + 1;




	DLOOP_Offset old_size = 0, old_extent = 0;
	DLOOP_Type   el_type = 0;
	DLOOP_Handle_get_size_macro(oldtype, old_size);
	DLOOP_Handle_get_extent_macro(oldtype, old_extent);
	DLOOP_Handle_get_basic_type_macro(oldtype, el_type);

	DLOOP_Dataloop *old_loop_ptr;
 
	DLOOP_Handle_get_loopptr_macro(oldtype, old_loop_ptr, flag);
 
	if (((old_loop_ptr->kind & DLOOP_KIND_MASK) == DLOOP_KIND_CONTIG)
    && (old_size == old_extent))
	{
			printf("ktaranov: Perform optimization: vec(n b s)[ctg(k)[type]] ----> vec(n bk sk)[type]\n");
			DLOOP_Count contig_count=  old_loop_ptr->loop_params.c_t.count;
 
			DLOOP_Dataloop *old_old_loop = old_loop_ptr->loop_params.c_t.dataloop;
			assert(old_old_loop!= old_loop_ptr && "not correct loop ptr");

			// update fields
 
			old_loop_ptr->kind = DLOOP_KIND_VECTOR | DLOOP_FINAL_MASK;
			old_loop_ptr->loop_params.v_t.dataloop = old_old_loop;
			old_loop_ptr->loop_params.v_t.count     = count;
			old_loop_ptr->loop_params.v_t.blocksize = blocklength * contig_count;
			old_loop_ptr->loop_params.v_t.stride    = (strideinbytes) ? stride :
	stride * old_extent;

		    *dlp_p     = old_loop_ptr;
	   		*dlsz_p    = old_loop_sz;
	   		*dldepth_p = old_loop_depth;
	   		return 0;
	}


    }


    if (is_builtin) {
		

		PREPEND_PREFIX(Dataloop_alloc)(DLOOP_KIND_VECTOR,
					       count,
					       &new_dlp,
					       &new_loop_sz);
		/* --BEGIN ERROR HANDLING-- */
		if (!new_dlp) return -1;
		/* --END ERROR HANDLING-- */
		DLOOP_Offset basic_sz = 0;
		DLOOP_Handle_get_size_macro(oldtype, basic_sz);
		new_dlp->kind = DLOOP_KIND_VECTOR | DLOOP_FINAL_MASK;

		if (flag == DLOOP_DATALOOP_ALL_BYTES)
		{

		    blocklength       *= basic_sz;
		    new_dlp->el_size   = 1;
		    new_dlp->el_extent = 1;
		    new_dlp->el_type   = MPI_BYTE;

	            if(!strideinbytes)
	                /* the stride was specified in units of oldtype, now
	                   that we're using bytes, rather than oldtype, we
	                   need to update stride. */
	                stride *= basic_sz;
		}
		else
		{
		    new_dlp->el_size   = basic_sz;
		    new_dlp->el_extent = new_dlp->el_size;
		    new_dlp->el_type   = oldtype;
		}
    }
    else /* user-defined base type (oldtype) */ {
 
	DLOOP_Dataloop *old_loop_ptr;
	int old_loop_sz = 0;

	DLOOP_Handle_get_loopptr_macro(oldtype, old_loop_ptr, flag);
	DLOOP_Handle_get_loopsize_macro(oldtype, old_loop_sz, flag);

	PREPEND_PREFIX(Dataloop_alloc_and_copy)(DLOOP_KIND_VECTOR,
						count,
						old_loop_ptr,
						old_loop_sz,
						&new_dlp,
						&new_loop_sz);
	/* --BEGIN ERROR HANDLING-- */
	if (!new_dlp) return -1;
	/* --END ERROR HANDLING-- */

	new_dlp->kind = DLOOP_KIND_VECTOR;
	DLOOP_Handle_get_size_macro(oldtype, new_dlp->el_size);
	DLOOP_Handle_get_extent_macro(oldtype, new_dlp->el_extent);
	DLOOP_Handle_get_basic_type_macro(oldtype, new_dlp->el_type);





    }

    /* vector-specific members
     *
     * stride stored in dataloop is always in bytes for local rep of type
     */
    new_dlp->loop_params.v_t.count     = count;
    new_dlp->loop_params.v_t.blocksize = blocklength;
    new_dlp->loop_params.v_t.stride    = (strideinbytes) ? stride :
	stride * new_dlp->el_extent;

    *dlp_p     = new_dlp;
    *dlsz_p    = new_loop_sz;
    *dldepth_p = new_loop_depth;

    return 0;
}
