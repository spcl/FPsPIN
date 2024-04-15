# FPsPIN: FPGA Whole-system demo for PsPIN

This is the the FPGA demo of sPIN, the streaming Process-In-Network paradigm.  The repo contains the PULP-based version of sPIN, PsPIN [PsPIN readme](https://github.com/spcl/pspin) for more information.

The project uses [Corundum](/README.corundum.md) as the base NIC platform.

This project was started by [Pengcheng Xu as a Masters thesis](https://doi.org/10.3929/ethz-b-000637676) project 

## Building the hardware

The hardware implementation has been tested on a [VCU1525](https://www.xilinx.com/products/boards-and-kits/vcu1525-a.html) board with Vivado 2020.2.  To build the hardware:

```console
(pwd: project root)
$ source /opt/Xilinx/Vivado/2020.2/settings64.sh # change accordingly
$ cd fpga/mqnic/VCU1525/fpga_100g/fpga_pspin
$ make
```

You will obtain `fpga.runs/impl_1/fpga.bit` for flashing onto the VCU1525.

## Building the software

The software is split into three parts: kernel module, host application, and NIC handler image.  The host application and handler image together form a PsPIN application.

### Kernel modules

Make sure you have the kernel headers for your running kernel before attempting to build the modules.  First, build the Corundum kernel modules for basic NIC functionality:

```console
(pwd: project root)
$ cd fpga/app/pspin/modules/mqnic
$ make
$ sudo make install
```

You will have `mqnic.ko` installed in your system.

Then, build the FPsPIN kernel module:
```console
(pwd: project root)
$ cd fpga/app/pspin/modules/mqnic_app_pspin
$ make
$ sudo make install
```

You will have `mqnic_app_pspin.ko` installed in your system.

### PsPIN application

We provide two demo applications:
- `icmp_ping`: implements a responder for the ICMP Ping (Echo) protocol
- `ping_pong`: implements a UDP responder that transforms incoming UDP packets and sends it back (e.g. with netcat)

The way to build them is the same.  We take `icmp_ping` as an example:

```console
(pwd: project root)
$ cd fpga/app/pspin/deps/pspin/examples/icmp_ping
$ make # this builds the handler image
$ make host # this builds the host application
```

## Testing

The test setup is an AMD64 host desktop/server with Ubuntu 20.04.4 LTS and Linux kernel `5.15.0-71-generic`.  We test the design on a PCIe-attached VCU1525; the JTAG USB cable should be attached to the host for programming the bitstream, and a Direct-Attached-Copper (DAC) cable should connect the two Ethernet ports of the FPGA card, forming a loopback.

First, program the bitstream over Vivado Hardware Manager.  Verify that the bitstream is correctly programmed by rescanning the PCIe bus and checking for a new Ethernet controller:

```console
$ sudo bash -c 'echo 1 > /sys/bus/pci/rescan'
$ lspci | grep 1234 # this should list a "Ethernet controller"
```

Next, load the kernel modules `mqnic.ko` (for the basic NIC functionalities) and `mqnic_app_pspin.ko` (for the PsPIN cluster in the NIC).  Verify by checking for the network interface and device file:

```console
$ sudo depmod -a
$ sudo modprobe mqnic mqnic_app_pspin
$ ip a # should have eth0 and eth1 present
$ ls /dev/pspin0 # should be a character special file
```

After verifying the previous step, run `setup-netns.sh` to move the two interfaces to two different network namespaces:
- `eth0` will be in namespace `pspin` and has the PsPIN cluster attached to it; IP address `10.0.0.1`
- `eth1` will be in namespace `bypass`; IP address `10.0.0.2`

```console
(pwd: project root)
$ cd fpga/app/pspin/utils
$ sudo ./setup-netns.sh on
Creating pspin namespace...
Creating bypass namespace...
<... output omitted ...>
Done!
```

Now we are ready for testing the application.  Start the standard output capture for the cluster in one terminal:
```console
(pwd: fpga/app/pspin/utils)
$ sudo ./cat_stdout.py --dump-files=True
Printing stdout for core 0.0
Dump files: yes
```

This will display the printf messages from the PsPIN cluster.  Next, in a new terminal window, start the host application, which automatically loads the NIC image (we use `icmp_ping` as an example):

```console
(pwd: fpga/app/pspin/deps/pspin/examples/icmp_ping)
$ sudo host/icmp-ping 0 # runs on the 0th execution context
(* OR *)
$ sudo ./icmp-ping 0 # when testing with prebuilt artifacts; pwd: artifacts/icmp_ping
Host DMA buffer: 32 pages
Mapped host dma at 0x7f0f841e0000
Host DMA physical addr: 0xfffffffffc760000, size: 131072
hh: 0 (size 0)
ph: 0x1d000492 (size 4096)
th: 0 (size 0)
Ruleset MODE_AND:
... 3 @ 0xffff0000 [8000000:8000000]
... 5 @ 0xff [1:1]
... 8 @ 0xff00 [800:800]
... 0 @ 0 [1:0]
Host flags at 0x1c000278
```

Verify that on the `cat_stdout.py` terminal window the following message is printed:

```text
HPU (0, 0) hello from hpu_entry
```

We can now generate the test traffic with `ping(8)`:

```console
$ sudo ip netns exec bypass ping 10.0.0.1 -f -c 100 # flood ping, 100 iterations
PING 10.0.0.1 (10.0.0.1) 56(84) bytes of data.

--- 10.0.0.1 ping statistics ---
100 packets transmitted, 100 received, 0% packet loss, time 4ms
rtt min/avg/max/mdev = 0.031/0.036/0.115/0.013 ms, ipg/ewma 0.043/0.034 ms
```

Finally, abort the host application by pressing <kbd>Ctrl</kbd>+<kbd>C</kbd>:

```console
...
^C
Received SIGINT, exiting...
Sum = 68170, count = 100
Handler cycles average: 681
Unloading cluster...
```

The `ping` roundtrip latency is `0.036 ms` on average, while the handler processing on the cluster took on average 681 cycles.  With the current cluster frequency at 40 MHz, this equals to `0.017 ms` of PsPIN processing latency.

### UDP ping test instructions

The instructions for testing UDP ping (`ping_pong`) stays largely the same.  The only difference is in generating packets.

With `netcat`, establish connection and verify that the typed in message will be echoed back:

```console
$ sudo ip netns exec bypass netcat -v -u 10.0.0.1 45555
Connection to 10.0.0.1 45555 port [udp/*] succeeded!
XXXXX
Hello
Hello
```

With `hping`, check for latency numbers:

```console
$ sudo ip netns exec bypass hping3 10.0.0.1 -2 -p 45555 -i u1000 -c 10
HPING 10.0.0.1 (eth1 10.0.0.1): udp mode set, 28 headers + 0 data bytes
len=46 ip=10.0.0.1 ttl=64 id=47144 seq=0 rtt=7.9 ms
<... output omitted ...>

--- 10.0.0.1 hping statistic ---
10 packets transmitted, 10 packets received, 0% packet loss
round-trip min/avg/max = 0.7/4.9/7.9 ms
```

The UDP ping end-to-end latency is significantly worse than ICMP ping due to latency in the host UDP stack on the tester (`bypass` NIC).
