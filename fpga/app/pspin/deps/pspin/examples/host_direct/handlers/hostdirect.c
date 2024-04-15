// Copyright 2020 ETH Zurich
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <handler.h>
#include <packets.h>
#include <spin_dma.h>


__handler__ void hostdirect_ph(handler_args_t *args) 
{
    spin_cmd_t xfer;
    spin_host_write(0xdeadbeef, 0xcafebebe, &xfer);
}

void init_handlers(handler_fn * hh, handler_fn *ph, handler_fn *th, void **handler_mem_ptr)
{
    volatile handler_fn handlers[] = {NULL, hostdirect_ph, NULL};
    *hh = handlers[0];
    *ph = handlers[1];
    *th = handlers[2];
}

