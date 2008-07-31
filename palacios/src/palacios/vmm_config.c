#include <palacios/vmm_config.h>
#include <palacios/vmm.h>
#include <palacios/vmm_debug.h>

#include <devices/serial.h>
#include <devices/keyboard.h>
#include <devices/8259a.h>
#include <devices/8254.h>
#include <devices/nvram.h>
#include <devices/generic.h>



int config_guest(struct guest_info * info, void * config_ptr) {

  struct guest_mem_layout * layout = (struct guest_mem_layout *)config_ptr;
  extern v3_cpu_arch_t v3_cpu_type;
  void * region_start;
  int i;

  
  v3_init_time(info);
  init_shadow_map(info);
  
  if (v3_cpu_type == V3_SVM_REV3_CPU) {
    info->shdw_pg_mode = NESTED_PAGING;
  } else {
    init_shadow_page_state(info);
    info->shdw_pg_mode = SHADOW_PAGING;
  }
  
  info->cpu_mode = REAL;
  info->mem_mode = PHYSICAL_MEM;
  
 
  init_vmm_io_map(info);
  init_interrupt_state(info);
  
  dev_mgr_init(info);
  
 
  //     SerialPrint("Guest Mem Dump at 0x%x\n", 0x100000);
  //PrintDebugMemDump((unsigned char *)(0x100000), 261 * 1024);
  if (layout->magic != MAGIC_CODE) {
    
    PrintDebug("Layout Magic Mismatch (0x%x)\n", layout->magic);
    return -1;
  }
  
  PrintDebug("%d layout regions\n", layout->num_regions);
  
  region_start = (void *)&(layout->regions[layout->num_regions]);
  
  PrintDebug("region start = 0x%x\n", region_start);
  
  for (i = 0; i < layout->num_regions; i++) {
    struct layout_region * reg = &(layout->regions[i]);
    uint_t num_pages = (reg->length / PAGE_SIZE) + ((reg->length % PAGE_SIZE) ? 1 : 0);
    void * guest_mem = V3_AllocPages(num_pages);
    
    PrintDebug("Layout Region %d bytes\n", reg->length);
    memcpy(guest_mem, region_start, reg->length);
    
    PrintDebugMemDump((unsigned char *)(guest_mem), 16);
    
    add_shadow_region_passthrough(info, reg->final_addr, reg->final_addr + (num_pages * PAGE_SIZE), (addr_t)guest_mem);
    
    PrintDebug("Adding Shadow Region (0x%x-0x%x) -> 0x%x\n", reg->final_addr, reg->final_addr + (num_pages * PAGE_SIZE), guest_mem);
    
    region_start += reg->length;
  }
  
      //     
  add_shadow_region_passthrough(info, 0x0, 0xa0000, (addr_t)V3_AllocPages(160));
  
  add_shadow_region_passthrough(info, 0xa0000, 0xc0000, 0xa0000); 
  //hook_guest_mem(info, 0xa0000, 0xc0000, passthrough_mem_read, passthrough_mem_write, NULL);
  
  
  // TEMP
  //add_shadow_region_passthrough(info, 0xc0000, 0xc8000, 0xc0000);
  
  if (1) {
    add_shadow_region_passthrough(info, 0xc7000, 0xc8000, (addr_t)V3_AllocPages(1));
    if (add_shadow_region_passthrough(info, 0xc8000, 0xf0000, (addr_t)V3_AllocPages(40)) == -1) {
      PrintDebug("Error adding shadow region\n");
    }
  } else {
    add_shadow_region_passthrough(info, 0xc0000, 0xc8000, 0xc0000);
    add_shadow_region_passthrough(info, 0xc8000, 0xf0000, 0xc8000);
  }
  
  
  //add_shadow_region_passthrough(info, 0x100000, 0x2000000, (addr_t)Allocate_VMM_Pages(8192));
  add_shadow_region_passthrough(info, 0x100000, 0x1000000, (addr_t)V3_AllocPages(4096));
  
  add_shadow_region_passthrough(info, 0x1000000, 0x8000000, (addr_t)V3_AllocPages(32768));
  
  // test - give linux accesss to PCI space - PAD
  add_shadow_region_passthrough(info, 0xc0000000,0xffffffff,0xc0000000);
  
  
  print_shadow_map(&(info->mem_map));

  
  {
    
    struct vm_device * nvram = create_nvram();
    //struct vm_device * timer = create_timer();
    struct vm_device * pic = create_pic();
    struct vm_device * keyboard = create_keyboard();
    struct vm_device * pit = create_pit(); 
    //struct vm_device * serial = create_serial();
    
    
#define GENERIC 1
    
#if GENERIC
    generic_port_range_type range[] = {
#if 1
      // Make the DMA controller invisible

      {0x00, 0x07, GENERIC_PRINT_AND_IGNORE},   // DMA 1 channels 0,1,2,3 (address, counter)
      {0xc0, 0xc7, GENERIC_PRINT_AND_IGNORE},   // DMA 2 channels 4,5,6,7 (address, counter)
      {0x87, 0x87, GENERIC_PRINT_AND_IGNORE},   // DMA 1 channel 0 page register
      {0x83, 0x83, GENERIC_PRINT_AND_IGNORE},   // DMA 1 channel 1 page register
      {0x81, 0x81, GENERIC_PRINT_AND_IGNORE},   // DMA 1 channel 2 page register
      {0x82, 0x82, GENERIC_PRINT_AND_IGNORE},   // DMA 1 channel 3 page register
      {0x8f, 0x8f, GENERIC_PRINT_AND_IGNORE},   // DMA 2 channel 4 page register
      {0x8b, 0x8b, GENERIC_PRINT_AND_IGNORE},   // DMA 2 channel 5 page register
      {0x89, 0x89, GENERIC_PRINT_AND_IGNORE},   // DMA 2 channel 6 page register
      {0x8a, 0x8a, GENERIC_PRINT_AND_IGNORE},   // DMA 2 channel 7 page register
      {0x08, 0x0f, GENERIC_PRINT_AND_IGNORE},   // DMA 1 misc registers (csr, req, smask,mode,clearff,reset,enable,mmask)
      {0xd0, 0xde, GENERIC_PRINT_AND_IGNORE},   // DMA 2 misc registers
#endif
      

#if 1      
      // Make the Serial ports invisible 

      {0x3f8, 0x3f8+7, GENERIC_PRINT_AND_IGNORE},      // COM 1
      {0x2f8, 0x2f8+7, GENERIC_PRINT_AND_IGNORE},      // COM 2
      {0x3e8, 0x3e8+7, GENERIC_PRINT_AND_IGNORE},      // COM 3
      {0x2e8, 0x2e8+7, GENERIC_PRINT_AND_IGNORE},      // COM 4
#endif


#if 1
      // Make the PCI bus invisible (at least it's configuration)

      {0xcf8, 0xcf8, GENERIC_PRINT_AND_IGNORE}, // PCI Config Address
      {0xcfc, 0xcfc, GENERIC_PRINT_AND_IGNORE}, // PCI Config Data
#endif
 
#if 0

      // Monitor the IDE controllers (very slow)

      {0x170, 0x178, GENERIC_PRINT_AND_PASSTHROUGH}, // IDE 1
      {0x376, 0x377, GENERIC_PRINT_AND_PASSTHROUGH}, // IDE 1
      {0x1f0, 0x1f8, GENERIC_PRINT_AND_PASSTHROUGH}, // IDE 0
      {0x3f6, 0x3f7, GENERIC_PRINT_AND_PASSTHROUGH}, // IDE 0
#endif
      

#if 0

      // Make the floppy controllers invisible

      {0x3f0, 0x3f2, GENERIC_PRINT_AND_IGNORE}, // Primary floppy controller (base,statusa/statusb,DOR)
      {0x3f4, 0x3f5, GENERIC_PRINT_AND_IGNORE}, // Primary floppy controller (mainstat/datarate,data)
      {0x3f7, 0x3f7, GENERIC_PRINT_AND_IGNORE}, // Primary floppy controller (DIR)
      {0x370, 0x372, GENERIC_PRINT_AND_IGNORE}, // Secondary floppy controller (base,statusa/statusb,DOR)
      {0x374, 0x375, GENERIC_PRINT_AND_IGNORE}, // Secondary floppy controller (mainstat/datarate,data)
      {0x377, 0x377, GENERIC_PRINT_AND_IGNORE}, // Secondary floppy controller (DIR)
      
#endif

#if 1

      // Make the parallel port invisible
      
      {0x378, 0x37f, GENERIC_PRINT_AND_IGNORE},

#endif

#if 1

      // Monitor graphics card operations

      {0x3b0, 0x3bb, GENERIC_PRINT_AND_PASSTHROUGH},
      {0x3c0, 0x3df, GENERIC_PRINT_AND_PASSTHROUGH},
      
#endif


#if 1
      // Make the ISA PNP features invisible

      {0x274, 0x277, GENERIC_PRINT_AND_IGNORE},
      {0x279, 0x279, GENERIC_PRINT_AND_IGNORE},
      {0xa79, 0xa79, GENERIC_PRINT_AND_IGNORE},
#endif


#if 1
      // Monitor any network card (realtek ne2000) operations 
      {0xc100, 0xc1ff, GENERIC_PRINT_AND_PASSTHROUGH},
#endif


#if 1
      // Make any Bus master ide controller invisible
      
      {0xc000, 0xc00f, GENERIC_PRINT_AND_IGNORE},
#endif


      //	  {0x378, 0x400, GENERIC_PRINT_AND_IGNORE}
      
      {0,0,0},  // sentinal - must be last
      
    };
    

    struct vm_device * generic = create_generic(range, NULL, NULL);
    
#endif
    
    v3_attach_device(info, nvram);
    //v3_attach_device(info, timer);
    v3_attach_device(info, pic);
    v3_attach_device(info, pit);
    v3_attach_device(info, keyboard);
    // v3_attach_device(info, serial);


#if GENERIC
    // Important that this be attached last!
    v3_attach_device(info, generic);
    
#endif
    
    PrintDebugDevMgr(info);
  }
  
  // give keyboard interrupts to vm
  // no longer needed since we have a keyboard device
  //hook_irq(&vm_info, 1);
  
#if 1
  // give floppy controller to vm
  v3_hook_irq_for_guest_injection(info, 6);
#endif
  
#if 1
  //primary ide
  v3_hook_irq_for_guest_injection(info, 14);
  
  // secondary ide
  v3_hook_irq_for_guest_injection(info, 15);
#endif
  

  info->rip = 0xfff0;
  info->vm_regs.rsp = 0x0;
  

  return 0;
}






















#if 0

    
    if (0) {
      
      //    add_shared_mem_range(&(vm_info.mem_layout), 0, 0x800000, 0x10000);    
      //    add_shared_mem_range(&(vm_info.mem_layout), 0, 0x1000000, 0);
      
      rip = (ulong_t)(void*)&BuzzVM;
      //  rip -= 0x10000;
      //    rip = (addr_t)(void*)&exit_test;
      //  rip -= 0x2000;
      vm_info.rip = rip;
      rsp = (addr_t)Alloc_Page();
      
      vm_info.vm_regs.rsp = (rsp +4092 );// - 0x2000;
      
            
    } else if (0) {
      //add_shared_mem_range(&(vm_info.mem_layout), 0x0, 0x1000, 0x100000);
      //      add_shared_mem_range(&(vm_info.mem_layout), 0x0, 0x100000, 0x0);
      
      /*
	shadow_region_t *ent = Malloc(sizeof(shadow_region_t));;
	init_shadow_region_physical(ent,0,0x100000,GUEST_REGION_PHYSICAL_MEMORY,
	0x100000, HOST_REGION_PHYSICAL_MEMORY);
	add_shadow_region(&(vm_info.mem_map),ent);
      */

      add_shadow_region_passthrough(&vm_info, 0x0, 0x100000, 0x100000);

      v3_hook_io_port(&vm_info, 0x61, &IO_Read, &IO_Write, NULL);
      v3_hook_io_port(&vm_info, 0x05, &IO_Read, &IO_Write_to_Serial, NULL);
      
      /*
	vm_info.cr0 = 0;
	vm_info.cs.base=0xf000;
	vm_info.cs.limit=0xffff;
      */
      //vm_info.rip = 0xfff0;

      vm_info.rip = 0;
      vm_info.vm_regs.rsp = 0x0;
    } else {
   
    }

#endif