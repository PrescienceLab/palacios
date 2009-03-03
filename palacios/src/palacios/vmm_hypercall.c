/* 
 * This file is part of the Palacios Virtual Machine Monitor developed
 * by the V3VEE Project with funding from the United States National 
 * Science Foundation and the Department of Energy.  
 *
 * The V3VEE Project is a joint project between Northwestern University
 * and the University of New Mexico.  You can find out more at 
 * http://www.v3vee.org
 *
 * Copyright (c) 2008, Jack Lange <jarusl@cs.northwestern.edu> 
 * Copyright (c) 2008, The V3VEE Project <http://www.v3vee.org> 
 * All rights reserved.
 *
 * Author: Jack Lange <jarusl@cs.northwestern.edu>
 *
 * This is free software.  You are permitted to use,
 * redistribute, and modify it as specified in the file "V3VEE_LICENSE".
 */

#include <palacios/vmm_hypercall.h>
#include <palacios/vmm.h>


void v3_init_hypercall_map(struct guest_info * info) {
    info->hcall_map.rb_node = NULL;
}


struct hypercall {
    uint_t id;
  
    int (*hcall_fn)(struct guest_info * info, uint_t hcall_id, void * priv_data);
    void * priv_data;
  
    struct rb_node tree_node;
};



static inline struct hypercall * __insert_hypercall(struct guest_info * info, struct hypercall * hcall) {
    struct rb_node ** p = &(info->hcall_map.rb_node);
    struct rb_node * parent = NULL;
    struct hypercall * tmp_hcall = NULL;

    while (*p) {
	parent = *p;
	tmp_hcall = rb_entry(parent, struct hypercall, tree_node);

	if (hcall->id < tmp_hcall->id) {
	    p = &(*p)->rb_left;
	} else if (hcall->id > tmp_hcall->id) {
	    p = &(*p)->rb_right;
	} else {
	    return tmp_hcall;
	}
    }

    rb_link_node(&(hcall->tree_node), parent, p);

    return NULL;
}


static inline struct hypercall * insert_hypercall(struct guest_info * info, struct hypercall * hcall) {
    struct hypercall * ret;

    if ((ret = __insert_hypercall(info, hcall))) {
	return ret;
    }

    v3_rb_insert_color(&(hcall->tree_node), &(info->hcall_map));

    return NULL;
}


static struct hypercall * get_hypercall(struct guest_info * info, uint_t id) {
    struct rb_node * n = info->hcall_map.rb_node;
    struct hypercall * hcall = NULL;

    while (n) {
	hcall = rb_entry(n, struct hypercall, tree_node);
    
	if (id < hcall->id) {
	    n = n->rb_left;
	} else if (id > hcall->id) {
	    n = n->rb_right;
	} else {
	    return hcall;
	}
    }

    return NULL;
}


int v3_register_hypercall(struct guest_info * info, uint_t hypercall_id, 
			  int (*hypercall)(struct guest_info * info, uint_t hcall_id, void * priv_data), 
			  void * priv_data) {

    struct hypercall * hcall = (struct hypercall *)V3_Malloc(sizeof(struct hypercall));

    hcall->id = hypercall_id;
    hcall->priv_data = priv_data;
    hcall->hcall_fn = hypercall;

    if (insert_hypercall(info, hcall)) {
	V3_Free(hcall);
	return -1;
    }

    return 0;
}


int v3_handle_hypercall(struct guest_info * info) {
    uint_t hypercall_id = *(uint_t *)&info->vm_regs.rax;

    struct hypercall * hcall = get_hypercall(info, hypercall_id);

    if (!hcall) {
	PrintError("Invalid Hypercall (%d not registered)\n", hypercall_id);
	return -1;
    }

    return hcall->hcall_fn(info, hypercall_id, hcall->priv_data);
}