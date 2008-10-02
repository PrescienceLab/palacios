#ifndef __IDE_H__
#define __IDE_H__


#ifdef __V3VEE__
#include <palacios/vmm_types.h>

#ifdef __V3_32BIT__
typedef long off_t;
typedef sint32_t ssize_t;
typedef unsigned int rd_bool;
typedef uchar_t Bit8u;
typedef ushort_t Bit16u;
typedef uint32_t Bit32u;
typedef uint64_t Bit64u;
#endif


typedef enum _sense {
      SENSE_NONE = 0, 
      SENSE_NOT_READY = 2, 
      SENSE_ILLEGAL_REQUEST = 5,
      SENSE_UNIT_ATTENTION = 6
} sense_t ;

typedef enum _asc {
      ASC_INV_FIELD_IN_CMD_PACKET = 0x24,
      ASC_MEDIUM_NOT_PRESENT = 0x3a,
      ASC_SAVING_PARAMETERS_NOT_SUPPORTED = 0x39,
      ASC_LOGICAL_BLOCK_OOR = 0x21
} asc_t ;



typedef struct  {
  unsigned cylinders;
  unsigned heads;
  unsigned sectors;
} device_image_t;




struct interrupt_reason_t {
  unsigned  c_d : 1; 
  unsigned  i_o : 1; 
  unsigned  rel : 1; 
  unsigned  tag : 5; 
};


struct controller_status {
  rd_bool busy;
  rd_bool drive_ready;
  rd_bool write_fault;
  rd_bool seek_complete;
  rd_bool drq;
  rd_bool corrected_data;
  rd_bool index_pulse;
  unsigned int index_pulse_count;
  rd_bool err;
};





struct  sense_info_t {
  sense_t sense_key;

  struct  {
    Bit8u arr[4];
  } information;

  struct  {
    Bit8u arr[4];
  } specific_inf;

  struct  {
    Bit8u arr[3];
  } key_spec;

  Bit8u fruc;
  Bit8u asc;
  Bit8u ascq;
};


struct  error_recovery_t {
  unsigned char data[8];
};

struct  cdrom_t {
  rd_bool ready;
  rd_bool locked;

  struct cdrom_interface * cd;

  uint32_t capacity;
  int next_lba;
  int remaining_blocks;

  struct  currentStruct {
    struct error_recovery_t error_recovery;
  } current;

};

struct  atapi_t {
  uint8_t command;
  int drq_bytes;
  int total_bytes_remaining;
};


typedef enum { IDE_NONE, IDE_DISK, IDE_CDROM } device_type_t;

struct controller_t  {
  struct controller_status status;
  Bit8u    error_register;
  Bit8u    head_no;

  union {
    Bit8u    sector_count;
    struct interrupt_reason_t interrupt_reason;
  };


  Bit8u    sector_no;

  union  {
    Bit16u   cylinder_no;
    Bit16u   byte_count;
  };

  Bit8u    buffer[2048]; 
  Bit32u   buffer_index;
  Bit32u   drq_index;
  Bit8u    current_command;
  Bit8u    sectors_per_block;
  Bit8u    lba_mode;

  struct  {
    rd_bool reset;       // 0=normal, 1=reset controller
    rd_bool disable_irq;     // 0=allow irq, 1=disable irq
  } control;

  Bit8u    reset_in_progress;
  Bit8u    features;
};




struct  drive_t {
  device_image_t  hard_drive;
  device_type_t device_type;
  // 512 byte buffer for ID drive command
  // These words are stored in native word endian format, as
  // they are fetched and returned via a return(), so
  // there's no need to keep them in x86 endian format.
  Bit16u id_drive[256];
  
  struct controller_t controller;
  struct cdrom_t cdrom;
  struct sense_info_t sense;
  struct atapi_t atapi;
  
  Bit8u model_no[41];
};


// FIXME:
// For each ATA channel we should have one controller struct
// and an array of two drive structs
struct  channel_t {
  struct drive_t drives[2];
  unsigned drive_select;
  
  Bit16u ioaddr1;
  Bit16u ioaddr2;
  Bit8u  irq;
};





struct ramdisk_t;






#endif // ! __V3VEE__


#endif

