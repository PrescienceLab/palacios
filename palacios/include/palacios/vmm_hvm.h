/*
 * This file is part of the Palacios Virtual Machine Monitor developed
 * by the V3VEE Project with funding from the United States National 
 * Science Foundation and the Department of Energy.  
 *
 * The V3VEE Project is a joint project between Northwestern University
 * and the University of New Mexico.  You can find out more at 
 * http://www.v3vee.org
 *
 * Copyright (c) 2015, The V3VEE Project <http://www.v3vee.org> 
 * All rights reserved.
 *
 * Author: Peter Dinda <pdinda@northwestern.edu>
 *
 * This is free software.  You are permitted to use,
 * redistribute, and modify it as specified in the file "V3VEE_LICENSE".
 */


#ifndef __VMM_HVM_H
#define __VMM_HVM_H


#ifdef __V3VEE__ 

#include <palacios/vmm_types.h>

struct v3_vm_hvm {
    uint8_t   is_hvm;
    uint32_t  first_hrt_core;
    uint64_t  first_hrt_gpa;
    struct v3_cfg_file *hrt_file;
};

struct v3_core_hvm {
    uint8_t   is_hrt;
};

struct v3_xml;

int v3_init_hvm();
int v3_deinit_hvm();

int v3_init_hvm_vm(struct v3_vm_info *vm, struct v3_xml *config);
int v3_deinit_hvm_vm(struct v3_vm_info *vm);


int v3_init_hvm_core(struct guest_info *core);
int v3_deinit_hvm_core(struct guest_info *core);


uint64_t v3_get_hvm_ros_memsize(struct v3_vm_info *vm);
uint64_t v3_get_hvm_hrt_memsize(struct v3_vm_info *vm);
int      v3_is_hvm_ros_mem_gpa(struct v3_vm_info *vm, addr_t gpa);
int      v3_is_hvm_hrt_mem_gpa(struct v3_vm_info *vm, addr_t gpa);

uint32_t v3_get_hvm_ros_cores(struct v3_vm_info *vm);
uint32_t v3_get_hvm_hrt_cores(struct v3_vm_info *vm);
int      v3_is_hvm_ros_core(struct guest_info *core);
int      v3_is_hvm_hrt_core(struct guest_info *core);


int      v3_hvm_should_deliver_ipi(struct guest_info *src, struct guest_info *dest);
void     v3_hvm_find_apics_seen_by_core(struct guest_info *core, struct v3_vm_info *vm, 
					uint32_t *start_apic, uint32_t *num_apics);

#endif /* ! __V3VEE__ */


#endif
