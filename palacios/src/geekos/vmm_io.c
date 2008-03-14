#include <geekos/vmm_io.h>
#include <geekos/string.h>
#include <geekos/vmm.h>

extern struct vmm_os_hooks * os_hooks;

void init_vmm_io_map(vmm_io_map_t * io_map) {
  io_map->num_ports = 0;
  io_map->head = NULL;
}



void add_io_hook(vmm_io_map_t * io_map, vmm_io_hook_t * io_hook) {
  vmm_io_hook_t * tmp_hook = io_map->head;

  if (!tmp_hook) {
    io_map->head = io_hook;
    io_map->num_ports = 1;
    return;
  } else {
    while ((tmp_hook->next)  && 
	   (tmp_hook->next->port <= io_hook->port)) {
      tmp_hook = tmp_hook->next;
    }
    
    if (tmp_hook->port == io_hook->port) {
      tmp_hook->read = io_hook->read;
      tmp_hook->write = io_hook->write;
      
      VMMFree(io_hook);
      return;
    } else if (!tmp_hook->next) {
      tmp_hook->next = io_hook;
      io_hook->prev = tmp_hook;
      io_map->num_ports++;
      
      return;
    } else {
      io_hook->next = tmp_hook->next;
      io_hook->prev = tmp_hook;
      
      tmp_hook->next = io_hook;
      if (io_hook->next) {
	io_hook->next->prev = io_hook;
      }
      
      io_map->num_ports++;
      return;
    }
  }
}

void hook_io_port(vmm_io_map_t * io_map, uint_t port, 
		  int (*read)(ushort_t port, void * dst, uint_t length),
		  int (*write)(ushort_t port, void * src, uint_t length)) {
  vmm_io_hook_t * io_hook = os_hooks->malloc(sizeof(vmm_io_hook_t));

  io_hook->port = port;
  io_hook->read = read;
  io_hook->write = write;
  io_hook->next = NULL;
  io_hook->prev = NULL;

  add_io_hook(io_map, io_hook);

  return;
}


void PrintDebugIOMap(vmm_io_map_t * io_map) {
  vmm_io_hook_t * iter = io_map->head;

  PrintDebug("VMM IO Map (Entries=%d)\n", io_map->num_ports);

  while (iter) {
    PrintDebug("IO Port: %hu (Read=%x) (Write=%x)\n", iter->port, iter->read, iter->write);
  }
}
