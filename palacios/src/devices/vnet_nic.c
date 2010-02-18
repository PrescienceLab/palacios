/* 
 * This file is part of the Palacios Virtual Machine Monitor developed
 * by the V3VEE Project with funding from the United States National 
 * Science Foundation and the Department of Energy.  
 *
 * The V3VEE Project is a joint project between Northwestern University
 * and the University of New Mexico.  You can find out more at 
 * http://www.v3vee.org
 *
 * Copyright (c) 2008, Lei Xia <lxia@northwestern.edu>
 * Copyright (c) 2008, The V3VEE Project <http://www.v3vee.org> 
 * All rights reserved.
 *
 * Author: Lei Xia <lxia@northwestern.edu>
 * 		 
 *
 * This is free software.  You are permitted to use,
 * redistribute, and modify it as specified in the file "V3VEE_LICENSE".
 */
//backend device for Virtio NIC

#include <palacios/vmm_vnet.h>
#include <palacios/vmm.h>
#include <palacios/vmm_dev_mgr.h>
#include <devices/lnx_virtio_pci.h>
#include <palacios/vm_guest_mem.h>
#include <devices/pci.h>


#ifndef CONFIG_DEBUG_VNET_NIC
#undef PrintDebug
#define PrintDebug(fmt, args...)
#endif

#define ETHERNET_PACKET_LEN 1514
struct eth_pkt {
    uint32_t size; //size of data
    char data[ETHERNET_PACKET_LEN];
}__attribute__((packed));

struct vnet_nic_state {
    char mac[6];
    struct guest_info *core;
    struct gen_queue * inpkt_q;
	
    void *frontend_data;
    int (*frontend_input)(struct v3_vm_info *info, 
		                    uchar_t * buf,
                                 uint32_t size,
                                 void *private_data);
};

//used when virtio_nic get a packet from guest and send it to the backend
static int vnet_send(uint8_t * buf, uint32_t len, void * private_data, struct vm_device *dest_dev){
    PrintDebug("Virito NIC: In vnet_send: guest net state %p\n", private_data);

    v3_vnet_send_rawpkt(buf, len, private_data);
    return 0;
}

static int register_frontend_input(void *backend_data, 
									  int (*frontend_input)(struct v3_vm_info *info, 
		                                                                              uchar_t * buf,
                                                                                           uint32_t size,
                                                                                           void *private_data), 
                                                            void *front_data){
    struct vnet_nic_state *dev = (struct vnet_nic_state *)backend_data;

    dev->frontend_data = front_data;
    dev->frontend_input = frontend_input;

    return 0;
}


static struct v3_dev_net_ops net_ops = {
    .send = vnet_send, 
    .register_input = register_frontend_input,
};

static int virtio_input(struct v3_vm_info *info, uchar_t * buf, uint32_t len, void * private_data){
    struct vnet_nic_state *vnetnic = (struct vnet_nic_state *)private_data;
	
    PrintDebug("Vnet-nic: In input: vnet_nic state %p\n", vnetnic);	

    return vnetnic->frontend_input(info, buf, len, vnetnic->frontend_data);
}

#if 0
static int sendto_buf(struct vnet_nic_dev_state *vnetnic_dev, uchar_t * buf, uint_t size) {
    struct eth_pkt *pkt;

    pkt = (struct eth_pkt *)V3_Malloc(sizeof(struct eth_pkt));
    if(pkt == NULL){
        PrintError("Vnet NIC: Memory allocate fails\n");
        return -1;
    }
  
    pkt->size = size;
    memcpy(pkt->data, buf, size);
    v3_enqueue(vnetnic_dev->inpkt_q, (addr_t)pkt);
	
    PrintDebug("Vnet NIC: sendto_buf: packet: (size:%d)\n", (int)pkt->size);

    return pkt->size;
}

/*
  *called in svm/vmx handler
  *iteative handled the unsent packet in incoming packet queues for
  *all virtio nic devices in this guest
  */
int v3_virtionic_pktprocess(struct guest_info * info)
{
    struct eth_pkt *pkt = NULL;
    struct virtio_net_state *net_state;
    int i;

    //PrintDebug("Virtio NIC: processing guest %p\n", info);
    for (i = 0; i < net_idx; i++) {
        while (1) {
            net_state = temp_net_states[i];
            if(net_state->dev->vm != info)
                break;

            pkt = (struct eth_pkt *)v3_dequeue(net_state->inpkt_q);
            if(pkt == NULL) 
                break;
			
            if (send_pkt_to_guest(net_state, pkt->data, pkt->size, 1, NULL)) {
                PrintDebug("Virtio NIC: %p In pkt_handle: send one packet! pt length %d\n", 
				net_state, (int)pkt->size);  
            } else {
                PrintDebug("Virtio NIC: %p In pkt_handle: Fail to send one packet, pt length %d, discard it!\n", 
				net_state, (int)pkt->size); 
            }
	
            V3_Free(pkt);
        }
    }
    
    return 0;
}


/*
  *called in svm/vmx handler
  *iteative handled the unsent packet in incoming packet queues for
  *all virtio nic devices in this guest
  */
int v3_vnetnic_pktprocess(struct guest_info * info)
{
 
    return 0;
}

#endif

//register a virtio device to the vnet as backend
int register_to_vnet(struct v3_vm_info *info,
						struct vnet_nic_state *vnet_nic,
						char *dev_name,
						uchar_t mac[6]){
    uchar_t brdmac[6] = {0xff,0xff,0xff,0xff,0xff,0xff};
    uchar_t zeromac[6] = {0,0,0,0,0,0};
    struct v3_vnet_route route;

    PrintDebug("Vnet-nic: register Vnet-nic device %s, state %p to VNET\n", dev_name, vnet_nic);
	
    int idx = v3_vnet_add_node(info, dev_name, mac, virtio_input, (void *)vnet_nic);

    if (idx < 0) return -1;

 //add default routes for each link edge device
    memcpy(&route.src_mac, zeromac, 6);
    memcpy(&route.dest_mac, mac, 6);
    route.src_mac_qual = MAC_ANY;
    route.dest_mac_qual = MAC_NONE;
    route.link_idx = idx;
    route.link_type = LINK_EDGE;
    route.src_link_idx = -1;
    route.src_type = LINK_ANY;
    v3_vnet_add_route(&route);

    memcpy(&route.dest_mac, brdmac, 6);
    memcpy(&route.src_mac, mac, 6);
    route.src_mac_qual = MAC_NOT;
    route.dest_mac_qual = MAC_NONE;
    route.link_idx = idx;
    route.link_type = LINK_EDGE;
    route.src_link_idx = -1;
    route.src_type = LINK_ANY;
    v3_vnet_add_route(&route);

    return 0;
}

static int vnet_nic_free(struct vm_device * dev) {
    return 0;
}

static struct v3_device_ops dev_ops = {
    .free = vnet_nic_free,
    .reset = NULL,
    .start = NULL,
    .stop = NULL,
};

static int vnet_nic_init(struct v3_vm_info * vm, v3_cfg_tree_t * cfg) {
    struct vnet_nic_state * vnetnic = NULL;
    char * name = v3_cfg_val(cfg, "name");

    v3_cfg_tree_t * frontend_cfg = v3_cfg_subtree(cfg, "frontend");

    vnetnic = (struct vnet_nic_state *)V3_Malloc(sizeof(struct vnet_nic_state));
    memset(vnetnic, 0, sizeof(struct vnet_nic_state));

    struct vm_device * dev = v3_allocate_device(name, &dev_ops, vnetnic);

    if (v3_attach_device(vm, dev) == -1) {
	PrintError("Could not attach device %s\n", name);
	return -1;
    }

    if (v3_dev_connect_net(vm, v3_cfg_val(frontend_cfg, "tag"), 
			   &net_ops, frontend_cfg, vnetnic) == -1) {
	PrintError("Could not connect %s to frontend %s\n", 
		   name, v3_cfg_val(frontend_cfg, "tag"));
	return -1;
    }

    vnetnic->inpkt_q = v3_create_queue();

    if(register_to_vnet(vm, vnetnic, name, vnetnic->mac) == -1)
      return -1;

    PrintDebug("Vnet-nic device %s initialized\n", name);

    return 0;
}

device_register("VNET_NIC", vnet_nic_init)