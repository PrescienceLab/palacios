#!/usr/bin/perl -w


print <<END

Welcome.  The purpose of this tool is to simplify the creation of
common forms of guests for the V3VEE environment on a Linux system.
These guests *should* work for any host embedding (e.g., Kitten) but
there may be hidden Linux assumptions.

The tool assumes you have already built Palacios, the Linux embedding,
and the Linux user-space tools.  If you haven't done this, hit CTRL-C
now, configure and build Palacios, the user-space tools, and run
v3_config_v3vee.pl.

This tool also assumes that you have the environment produced by
v3_config_v3vee.pl sourced:

  source ./ENV

What this tool builds is a directory that contains a guest
configuration file (the ".pal" file) and its dependent files. Note
that lots of additional functionality is possible beyond what can be
configured with this tool.  The precise functionality depends on the
version and branch of Palacios, and what was configured into it when
it was built.  To access such functionality, you need to write your
own .pal file, or use one generated by this tool as a basis.

Any .pal guest configuration file is instantiated as a VM in the
following way:

  cd guest
  v3_create -b guest.pal name_of_guest

Any files (disk images) that your guest configuration depends on
must be accessible when v3_create is run.  

Once the VM is instantiated, you can then launch it:

  v3_launch /dev/v3-vmN  (N is given by the v3_create command)

We will configure your guest via a sequence of questions.

END
;

$pdir = $ENV{PALACIOS_DIR};

if (!defined($pdir)) { 
  print "Please set PALACIOS_DIR (you probably have not sourced ENV) and try again\n";
  exit -1;
}

$otherbios = get_palacios_core_feature($pdir,"V3_CONFIG_OTHERBIOS");
$otherbios = !defined($otherbios) ? 0 : $otherbios eq "y" ? 1: 0;
if ($otherbios) {
  print "Your Palacios installation is set up for a custom BIOS. \n";
  print "You probably do NOT want to use this tool...  Continue ? [n] : ";
  if (get_user("n") eq "n") { exit -1; }
}


$name = "myguest";
print "What is the name of your guest? [$name] : ";
$name = get_user($name);

$dir = "./$name";
print "What is the directory into which we will put your guest? [$dir] : ";
$dir = get_user($dir);
if (!mkdir($dir)) { 
  print "Unable to create the directory\n";
  exit -1;
}

$config{numcores} = quant_question("How many cores will your guest have?", 1);

$config{mem} = quant_question("How much memory should it have in MB?", 256);

if ($config{numcores}>1) { 
  print "Do you want to to produce a NUMA configuration and mapping for your guest? [n] : ";
  if (get_user("n") eq "y") { 
    do_numa_config(\%config,$pdir);
  }
}

do_swapping(\%config, $pdir);

print "We will give your guest the default performance tuning characteristics\n";
$config{perftune_block} .= <<PERFTUNE
  <group name="yield">
   <strategy>friendly</strategy>
   <threshold>1000</threshold>
   <time>1000</time>
  </group>
PERFTUNE
;

print "We will give your guest the default host scheduler interaction characteristics\n";
$config{schedule_hz_block} .= " <schedule_hz>100</schedule_hz>\n";


$config{telemetry} = yn_question("Do you want telemetry (information about guest exits) ?", "y", "enable", "disable");


$config{paging_mode} = yn_question("Do you want to use nested paging if possible on your hardware?\n  This will often (but not always) perform faster than shadow paging. ", "y", "nested", "shadow");

$config{large_pages} = yn_question("Do you want to use large pages if possible on your hardware?\n  This will often (but not always) perform faster. ", "n", "true", "false");

print "We will give your guest the default shadow paging strategy for when shadow paging is used.\n";
$config{shadow_strategy} = "VTLB";


$config{memmap_block} = " <!-- there are no passthrough memory regions, but you can add them using\n".
                         "     the <memmap> syntax described in the manual -->\n";

if (is_palacios_core_feature_enabled($pdir, "V3_CONFIG_EXT_VMWARE")) {
  print "We will include the VMware Personality Extension since your Palacios build has it enabled\n";
  $config{extensions_block} .= "  <extension name=\"VMWARE_IFACE\"></extension>\n";
}

#
# Basic debugging
#
do_device(\%config, $pdir, "V3_CONFIG_BOCHS_DEBUG", "BOCHS_DEBUG", "bios_debug");
do_device(\%config, $pdir, "V3_CONFIG_OS_DEBUG", "OS_DEBUG", "os_debug");

#
# Interrupt control
#
#
do_device(\%config, $pdir, "V3_CONFIG_PIC", "8259A", "PIC", 1);  # must have
if ($config{numcores}==1 && is_palacios_core_feature_enabled($pdir,"V3_CONFIG_BOCHSBIOS")) {
  print "This is a single core guest and your Palacios setup uses the legacy BOCHS BIOS.\n";
  print " Do you want to have only the legacy (pre-APIC) interrupt controller logic? [n] :";
  if (get_user("n") eq "y") { 
    goto intr_done;
  }
}
do_device(\%config, $pdir, "V3_CONFIG_APIC", "LAPIC", "apic", 1); # must have
do_device(\%config, $pdir, "V3_CONFIG_IO_APIC", "IOAPIC", "ioapic", 1, undef, "    <apic>apic</apic>\n"); 


#
# PCI buses and north/south bridge - all must haves
#
do_device(\%config, $pdir, "V3_CONFIG_PCI", "PCI", "pci0",1); # must have
do_device(\%config, $pdir, "V3_CONFIG_I440FX", "i440FX", "northbridge",1, undef, "    <bus>pci0</bus>\n"); #must have
do_device(\%config, $pdir, "V3_CONFIG_PIIX3", "PIIX3", "southbridge",1, undef, "    <bus>pci0</bus>\n"); #must have

#
# MPTABLE for legacy BIOS.  Innocuous for SEABIOS or OTHERBIOS
#
#
if (is_palacios_core_feature_enabled($pdir,"V3_CONFIG_MPTABLE")) {
  print "We will include a classic MPTABLE constructor to describe your machine to the guest\n";
  add_device(\%config, "MPTABLE", "mptable");
} else {
  if ($config{numcores}>1 &&  is_palacios_core_feature_enabled($pdir,"V3_CONFIG_BOCHSBIOS")) {
    print "This is a multicore guest, and your Palacios configuration uses the classic BOCHS BIOS\n".
      "but does not have the MPTABLE constructor enabled...  This guest will almost\n".
	"certainly fail to work.  Do you want to continue anyway? [n] :";
    if (get_user("n") eq "n") { 
      exit -1;
    }
  }
}


# 
# Legacy timer
#
do_device(\%config, $pdir, "V3_CONFIG_PIT", "8254_PIT", "PIT",1); # must have

#
# Keyboard and mouse (PS/2 controller)
#
do_device(\%config, $pdir, "V3_CONFIG_KEYBOARD", "KEYBOARD", "keyboard",1); #must have


#
# Displays, Consoles, Serial
#
print "\nWe will now consider consoles and serial ports.\n\n";
do_consoles_and_ports(\%config, $pdir);


#
# Storage controllers and devices (attached to PCI bus)
#
#
print "\nWe will now consider storage controllers and devices.\n\n";
do_storage(\%config, $pdir, $dir, $name, "pci0", "southbridge");




#
# Network interfaces (attached to PCI bus)
#
#
print "\nWe will now consider network interfaces.\n\n";
do_network(\%config, $pdir, $dir, $name, "pci0", "southbridge");


#
# Sanity-check - is there something bootable?
#
#
if (!($config{havecd} && !($config{havehd}))) {
  print "The guest's storage configuration does not have either a CD or an HD.  \n";
  print "This means the guest BIOS will have nothing local to boot.  \n";
  if (!($config{havenic})) { 
    print "The guest also does does not have a NIC, which means the BIOS cannot\n";
    print "do a network boot.\n";
  } else {
    print "The guest does have a NIC, so a network boot is possible, if the\n";
    print "BIOS supports it.\n";
  }
  print "If this is not your intent, you probably want to CTRL-C and try again.\n";
}

print "The BIOS boot sequence will be set to CD,HD.   If you need to change this\n";
print "later, edit the <bootseq> block within the NVRAM device.\n";

#
# NVRAM 
#
# Note: do_storage *must* have placed an IDE named ide0 in order for this to work
#
do_device(\%config, $pdir, "V3_CONFIG_NVRAM", "NVRAM", "nvram", 1, undef, "     <storage>ide0</storage>\n     <bootseq>cd,hd</bootseq>\n"); #must have

#
#
# Generic Catch-all Device
#
do_generic(\%config, $pdir);


open(PAL,">$dir/$name.pal") or die "Cannot open $dir/$name.pal\n";

$target = PAL;

print $target "<vm class=\"PC\">\n\n";
print $target file_setup(\%config), "\n";
print $target memory_setup(\%config), "\n";
print $target swapping_setup(\%config), "\n";
print $target paging_setup(\%config), "\n";
print $target memmap_setup(\%config), "\n";
print $target numa_setup(\%config), "\n";
print $target core_setup(\%config), "\n";
print $target schedule_setup(\%config), "\n";
print $target perftune_setup(\%config), "\n";
print $target telemetry_setup(\%config), "\n";
print $target extensions_setup(\%config), "\n";
print $target device_setup(\%config), "\n";
print $target "</vm>\n";

close(PAL);

print "\n\nYour guest is now ready in the directory $dir\n\n";
print "To run it, do:\n\n";
print "  cd $dir\n";
print "  v3_create -b $name.pal $name\n";
print "  v3_launch /dev/v3-vmN (N given by v3_create)\n\n";
print "Other useful tools:\n\n";
print "  v3_console (CGA console)\n";
print "  v3_stream (connect to stream, for example, serial port)\n\n";

exit;


sub quant_question {
  my ($ques, $default) = @_;

  print $ques." [$default] : ";
  
  return get_user($default);
}

sub yn_question {
  my ($ques, $default, $yans, $nans) = @_;
  
  my $ans;
  
  print $ques." [$default] : ";
  $ans = get_user($default);
  
  if (substr($ans,0,1) eq 'y' || substr($ans,0,1) eq 'Y') { 
    return $yans;
  } else {
    return $nans;
  }
}

sub do_numa_config {
  my ($cr, $pdir) =@_;
  my %numa;
  my $numpnodes;
  my $numpcores;
  my $numvnodes;
  my $numvcores;
  my $memblock="";
  my $pernode;
  my $lastnode;
  my $i;
  my @vnodemap;
  my @vcoremap;
  my $canauto=1;

  %numa = get_numa_data();

  $numvcores = $cr->{numcores};

  print "NUMA configuration involves the following:\n";
  print " 1. Definition of virtual NUMA nodes and their corresponding regions of guest physical memory\n";
  print " 2. Mapping of virtual NUMA nodes to physical NUMA nodes\n";
  print " 3. Mapping of virtual cores to virtual NUMA nodes\n";
  print " 4. Mapping of virtual cores to physical cores\n";
  print "Your guest contains ".$numvcores." virtual  cores.\n";
  print "This host contains ".$numa{numcores}." physical cores and ".$numa{numnodes}." physical nodes.\n";
  print "How many physical NUMA nodes does your target hardware have? [".$numa{numnodes}."] ? ";
  $numpnodes=get_user($numa{numnodes});
  $canauto=0 if ($numpnodes > $numa{numnodes});
  print "How many physical cores does your target hardware have? [".$numa{numcores}."] ? ";
  $numpcores=get_user($numa{numcores});
  $canauto=0 if ($numpcores > $numa{numcores});
  do {
    print "How many virtual NUMA nodes do you want? (up to $numvcores) for auto) [2] : ";
    $numvnodes=get_user("2");
  } while ($numvnodes<=0 || $numvnodes>$numvcores);
  $cr->{numnodes} = $numvnodes;
  $pernode = int(($cr->{mem}*1024*1024)/$numvnodes);
  $lastnode = $pernode + ($cr->{mem}*1024*1024)-$pernode*$numvnodes;
  print "Your guest has ".$cr->{mem}." MB of RAM, which we have defined and mapped like this:\n";
  for ($i=0;$i<$numvnodes;$i++) {
    my $start=$i*$pernode;
    my $end=(($i==($numvnodes-1)) ? $start+$lastnode : $start+$pernode);
    my $pnode = $i % $numpnodes;
    $vnodemap[$i]=$pnode;
    $start=sprintf("0x%x",$start);
    $end=sprintf("0x%x",$end);
    print "vnode $i : GPA $start to GPA $end : pnode $pnode\n";
    push @{$cr->{nodes}}, { start=>$start, end=>$end, vnode=>$i, pnode=>$pnode};
  }
  my $doauto=0;
  if ($canauto) { 
    print "We can now automatically map virtual cores to virtual NUMA nodes and physical CPUs using strided assignment\n";
    print "assuming *this host's* NUMA configuration.  Or you can enter the assignments manually. \n";
    print "  Which would you prefer {auto,manual} [auto] ? : ";
    $doauto=1 if  (get_user("auto") eq "auto");
  } else {
    print "Automatic mapping of virtual cores to virtual NUMA nodes and physical CPUs is not possible\n";
    print "given your host configuration.   Please configure manually below.\n";
    $doauto=0;
  }
  if ($doauto) { 
    for ($i=0;$i<$numvcores;$i++) { 
      my $vnode = $i % $numvnodes;
      my $pnode = $vnodemap[$vnode];
      my $pcores = $numa{"node$pnode"}{cores};
      my $numpcores_per_pnode = $#{$pcores}+1; # assumes identical number on each node...
      my $pcore = $numa{"node$pnode"}{cores}->[int($i/$numpnodes) % $numpcores_per_pnode];
      print "vcore $i : vnode $vnode : pnode $pnode : pcore $pcore\n";
      $cr->{"core$i"}{pcore} = $pcore;
      $cr->{"core$i"}{vnode} = $vnode;
    }
  } else {
    for ($i=0;$i<$numvcores;$i++) { 
      print "What is the virtual NUMA node for virtual core $i ? [] : ";
      my $vnode = get_user("");
      my $pnode = $vnodemap[$vnode];
      print "That maps to physical NUMA node $pnode.\n";
      print "What is the physical core for virtual core $i ? [] : ";
      my $pcore = get_user("");
      print "vcore $i : vnode $vnode : pnode $pnode : pcore $pcore\n";
      $cr->{"core$i"}{pcore} = $pcore;
      $cr->{"core$i"}{vnode} = $vnode;
    }
  }
  $cr->{numa}=1;
}


sub get_numa_data() {
  my $line;
  my $maxnode=0;
  my $maxcpu=0;
  my %numa;

  open (N, "numactl --hardware |");
  while ($line=<N>) { 
    if ($line=~/^node\s+(\d+)\s+cpus:\s+(.*)$/) { 
      my $node=$1;
      my @cpus = split(/\s+/,$2);
      my $cpu;
      if ($node>$maxnode) { $maxnode=$node; }
      foreach $cpu (@cpus) { 
	if ($cpu>$maxcpu) { $maxcpu=$cpu; }
      }
      $numa{"node$node"}{cores}=\@cpus;
    }
  }
  $numa{numnodes}=$maxnode+1;
  $numa{numcores}=$maxcpu+1;
  return %numa;
}


sub do_swapping {
  my ($cr, $pdir) = @_;

  my $canswap = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_SWAPPING");
  my $mem = $cr->{mem};

  if ($canswap) { 
    #Config for swapping
    $cr->{swapping} = yn_question("Do you want to use swapping?", "n", "y", "n");
    
    if ($cr->{swapping} eq "y") { 
      $cr->{swap_alloc} = quant_question("How much memory do you want to allocate [MB] ?", $mem/2);
      print "We will use the default swapping strategy.\n";
      $cr->{swap_strat} = "default";
      print "What file do you want to swap to? [./swap.bin] ";
      $cr->{swap_file} = get_user("./swap.bin");
    }
  }

} 

sub do_device {
  my ($cr,$pdir,$feature, $class, $id, $hardfail, $optblob, $nestblob) =@_;

  if (is_palacios_core_feature_enabled($pdir, $feature)) {
    print "We will include a $class since your Palacios build has it enabled\n";
    add_device(\%config, $class, $id, $optblob, $nestblob);
  } else {
    if (defined($hardfail) && $hardfail) { 
      print "Wow, your Palacios build doesn't have a $class... We can't live without that...\n";
      exit -1;
    } else {
      print "Not configuring a $class since your Palacios build doesn't have it enabled\n";
    }
  }
}

sub do_consoles_and_ports {
  my ($cr, $pdir) = @_;

  my $cga = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_CGA");
  my $curses = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_CURSES_CONSOLE");
  my $cons = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_CONSOLE");
  my $cancga = $cga && $curses && $cons;
  my $vga = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_VGA");
  my $gcons = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_GRAPHICS_CONSOLE");
  my $canvga = $vga && $gcons;
  my $serial = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_SERIAL_UART");
  my $charstream = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_CHAR_STREAM");
  my $stream = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_STREAM");
  my $canserial = $serial && $charstream && $stream;
  my $virtioconsole = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_LINUX_VIRTIO_CONSOLE");
  my $canvirtioconsole = $virtioconsole; # probably need to verify frontend
  my $paragraph = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_PARAGRAPH");
  my $canparagraph = $paragraph && $gcons;

  print "Your Palacios configuration allows the following options:\n";
  print "  * CGA: classic 80x25 text-only PC console (common option): ".($cancga ? "available\n" : "NOT AVAILABLE\n");
  print "  * VGA: classic 640x480 graphical PC console (uncommon option): ".($canvga ? "available\n" : "NOT AVAILABLE\n");
  print "  * SERIAL: classic PC serial ports (common option): ".($canserial ? "available\n" : "NOT AVAILABLE\n");
  print "  * VIRTIO: Linux Virtio Console (uncommon option): ".($canvirtioconsole ? "available\n" : "NOT AVAILABLE\n");
  print "  * PARAGRAPH: Paravirtualized graphics card (uncommon option): ".($canparagraph ? "available\n" : "NOT AVAILABLE\n");
  print "The CGA and VGA options are mutually exclusive\n";
  print "THe VGA and PARAGRAPH options are mutually exclusive\n";
  
  if (!($cancga || $canvga || $canserial || $canvirtioconsole)) { 
    print "Hmm... No console mechanism is enabled in your Palacios build...\n";
    print "  This is probably not what you want...\n";
  }
  
  $didcga=0;
  if ($cancga) { 
    print "Do you want to use CGA as a console? [y] : ";
    if (get_user("y") eq "y") { 
      add_device(\%config, "CGA_VIDEO", "cga", "passthrough=\"disable\"");
      add_device(\%config, "CURSES_CONSOLE", "console", undef, 
		 "    <frontend tag=\"cga\" />\n".
		 "    <tty>user</tty>\n");
      $didcga=1;
    }
  }
  
  $didvga=0;
  if ($canvga && !$didcga) { 
    print "Do you want to use VGA as a console? [n] : ";
    if (get_user("n") eq "y") { 
      add_device(\%config, "VGA", "vga", "passthrough=\"disable\" hostframebuf=\"enable\"");
      # there is no gconsole device
      $didvga=1;
    }
  }
  
  $didserial=0;
  if ($canserial) {
    print "You can include serial ports whether you use them for a console or not\n";
    print "Note that you must configure your guest to place its console onto a serial port\n";
    print "for it to be visible\n";
    print "Do you want to include the serial ports (COM1..4) ? [y] : ";
    if (get_user("y") eq "y") {
      add_device(\%config,"SERIAL","serial");
      add_device(\%config,"CHAR_STREAM","stream1","name=\"com1\"", "    <frontend tag=\"serial\" com_port=\"1\" />\n");
      add_device(\%config,"CHAR_STREAM","stream2","name=\"com2\"", "    <frontend tag=\"serial\" com_port=\"2\" />\n");
      add_device(\%config,"CHAR_STREAM","stream3","name=\"com3\"", "    <frontend tag=\"serial\" com_port=\"3\" />\n");
      add_device(\%config,"CHAR_STREAM","stream4","name=\"com4\"", "    <frontend tag=\"serial\" com_port=\"4\" />\n");
      $didserial=1;
    }
  }
  
  
  $didvirtioconsole=0;
  if ($canvirtioconsole) {
    print "Do you want to add a VIRTIO console? [n] : ";
    if (get_user("n") eq "y") { 
      add_device(\%config,"LNX_VIRTIO_CONSOLE","virtio-cons",undef,"    <bus>pci0</bus>\n");
      print "NOTE: no backend for the VIRTIO console is currently configured\n";
      $didvirtioconsole=1;
    }
  }
  
  $didparagraph=0;
  if ($canparagraph && !$didvga) {
    print "Do you want to add a PARAGRAPH graphics card? [n] : ";
    if (get_user("n") eq "y") {
      add_device(\%config, "PARAGRAPH", "paragraph", undef,  
		 "    <bus>pci0</bus>\n".
		 "    <mode>gcons_mem</bus>\n");
      $didparagraph=1;
    }
  }
  
  if (!($didcga || $didvga || $didserial || $didvirtioconsole || $didparagraph)) { 
    print "You have configured your guest without any obvious way of interacting with it....\n";
    print "  This is probably not what you want...\n";
  } 

} 


sub do_network {
  my ($cr,$pdir,$dir,$name, $pcibus)=@_;
  my $canvnet = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_VNET");
  my $canbridge = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_NIC_BRIDGE");
  my $canoverlay = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_VNET_NIC") && $canvnet; 
  my $canvirtio = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_LINUX_VIRTIO_NET"); 
  my $canvirtiovnet = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_LINUX_VIRTIO_VNET"); # not sure...
  my $canne2k = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_NE2K"); 
  my $canrtl8139 = is_palacios_core_feature_enabled($pdir,"V3_CONFIG_RTL8139"); 
  my @devs;
  my @backends;
  my $front;
  my $back;
  my $num;
  my @test;
  my $mac;

  push @devs, "virtio" if $canvirtio;
  push @devs, "rtl8139" if $canrtl8139;
  push @devs, "ne2000" if $canne2k;

  push @backends, "bridge" if $canbridge;
  push @backends, "vnet" if $canoverlay;

  if ($#devs==-1) { 
    print "You have no network device implementations enabled in your Palacios build, so we are skipping networking\n";
    return -1;
  }
  
  if ($#backends==-1) { 
    print "You have no network device backends enabled in your Palacios build, so we are skipping networking\n";
    return -1;
  }


  $num=0;
  while (1) { 
    last if (!yn_question("Do you want to add ".($num==0 ? "a" : "another")." network device?","n",1,0));
    print "This requires the addition of the frontend device (the NIC) and a backend device.\n";
    print "Frontends in Palacios include:\n";
    print "  * Virtio NIC (paravirtualized - common) : ".($canvirtio? "available" : "UNAVAILABLE")."\n";
    print "  * RTL8139 NIC (uncommon) : ".($canrtl8139? "available" : "UNAVAILABLE")."\n";
    print "  * NE2000 NIC (uncommon) : ".($canne2k? "available" : "UNAVAILABLE")."\n";
    print "Which frontend do you want to add? {".join(", ", @devs)."} : ";
    $front = get_user("");
    @test = grep { /^$front$/ } @devs;
    if ($#test!=0) { 
      print "Unknown frontend\n"; 
      next;
    }
    print "Backends in Palacios include:\n";
    print "  * Bridge (direct attach to host NIC - common) : ".($canbridge? "available" : "UNAVAILABLE")."\n";
    print "  * VNET overlay (uncommon) : ".($canoverlay ? "available" : "UNAVAILABLE")."\n";
    print "Which backend do you want to add? {".join(", ", @backends)."} : ";
    $back = get_user("");
    @test = grep { /^$back/ } @backends;
    if ($#test!=0) { 
      print "Unknown backend\n"; 
      next;
    }
    $mac=gen_macaddr();
    print "What MAC address do you want your NIC to have? [$mac] : ";
    $mac=get_user($mac);
    if ($front eq "virtio") {
       add_device($cr,"LNX_VIRTIO_NIC","net$num",undef,
                  "    <bus>$pcibus</bus>\n".
                  "    <mac>$mac</mac>\n".
                  "    <model mode=\"guest-driven\" />\n");
       print "The device is configured with default guest-driven operation\n";
    }
    if ($front eq "rtl8139") {
       add_device($cr,"RTL8139","net$num",undef,
                  "    <bus>$pcibus</bus>\n".
                  "    <mac>$mac</mac>\n");
    }
    if ($front eq "ne2000") {
       add_device($cr,"NE2000","net$num",undef,
                  "    <bus>$pcibus</bus>\n".
                  "    <mac>$mac</mac>\n");
    }

    if ($back eq "bridge") { 
       my $host;
       print "What is the name of the host NIC you want to bridge to? [eth0] : ";
       $host=get_user("eth0");
       add_device($cr,"NIC_BRIDGE","net$num-back",undef,
                  "    <frontend tag=\"net$num\" />\n".
                  "    <hostnic name=\"$host\" />\n");
    }

    if ($back eq "vnet") { 
       add_device($cr,"VNET_NIC","net$num-back",undef,
                  "    <frontend tag=\"net$num\" />\n");
       print "Important: In order to use the VNET overlay, you must also create routes at run-time via /proc/v3vee/vnet\n";
    }
    $num++;
  }

  if ($num>0) { 
    $cr->{havenic}=1;
  }
 }


sub gen_macaddr {
  return sprintf("%02X:%02X:%02X:%02X:%02X:%02X",
		 int(rand(256)),
		 int(rand(256)),
		 int(rand(256)),
		 int(rand(256)),
		 int(rand(256)),
		 int(rand(256)));
}
						 

sub do_storage {
  my ($cr,$pdir,$dir,$name,$pcibus,$controller)=@_;

  # 
  # IDE controller
  #
  do_device($cr, $pdir, "V3_CONFIG_IDE", "IDE", "ide0",1,undef,
	    "    <bus>$pcibus</bus>\n".
	    "    <controller>$controller</controller>\n" ); # must have
  print "You can attach up to four storage devices to the storage controller \"ide\"\n";
  do_storage_backend($cr, $pdir, $dir, $name, "ide0", "0_0", 
		     "     <bus_num>0</bus_num>\n".
		     "     <drive_num>0</drive_num>\n");
  do_storage_backend($cr, $pdir, $dir, $name, "ide0", "0_1", 
		   "     <bus_num>0</bus_num>\n".
		   "     <drive_num>1</drive_num>\n");
  do_storage_backend($cr, $pdir, $dir, $name, "ide0", "1_0", 
		     "     <bus_num>1</bus_num>\n".
		     "     <drive_num>0</drive_num>\n");
  do_storage_backend($cr, $pdir, $dir, $name, "ide0", "1_1", 
		     "     <bus_num>1</bus_num>\n".
		   "     <drive_num>1</drive_num>\n");
  
  if (is_palacios_core_feature_enabled($pdir,"V3_CONFIG_LINUX_VIRTIO_BLOCK")) { 
    print "You can attach VIRTIO block devices.  How many do you need? [0] : ";
    my $num = get_user("0");
    my $i;
    for ($i=0;$i<$num;$i++) { 
      add_device($cr,"LNX_VIRTIO_BLK","virtioblk$i",undef,"    <bus>$pcibus</bus>\n");
      do_storage_backend($cr, $pdir, $dir, $name, "virtioblk$i", "data$i", "");
    }
  }

}      



sub do_storage_backend {
  my ($cr, $pdir, $dir, $name, $frontend, $loc, $frontendblock) = @_;
  my ($canramdisk, $canfiledisk, $cannetdisk, $cantmpdisk);
  my @devs=("cd","hd","nothing");
  my @disks;
  my $type;
  my @type;
  my $file;
  my $size;

  $canramdisk = is_palacios_core_feature_enabled($pdir, "V3_CONFIG_RAMDISK");
  $canfiledisk = is_palacios_core_feature_enabled($pdir, "V3_CONFIG_FILEDISK");
  $cannetdisk = is_palacios_core_feature_enabled($pdir, "V3_CONFIG_NETDISK");
  $cantmpdisk = is_palacios_core_feature_enabled($pdir, "V3_CONFIG_TMPDISK");
  push @disks, "ramdisk" if $canramdisk;
  push @disks, "filedisk" if $canramdisk;
  push @disks, "netdisk" if $cannetdisk;
  push @disks, "tmpdisk" if $cantmpdisk;


  if (!$canramdisk && !$canfiledisk && !$cannetdisk && !$cantmpdisk) {
    print "You have no storage implementations enabled in your Palacios build, so it is impossible\n";
    print "to add anything to storage controller \"$frontend\" location \"$loc\"\n";
    return -1;
  }
   

  while (1) { 
    print "What do you want to attach to storage controller \"$frontend\" location \"$loc\"\n";
    print "  Your options are {".join(", ",@devs)."} [nothing] : ";
    $what = get_user("nothing");
    @test = grep { /^$what$/ } @devs;
    next if $#test!=0;
    if ($what eq "nothing") {
      return;
    }
    print "A storage device requires one of the following implementations\n";
    print "  * RAMDISK - the data is kept in memory (common) : ".($canramdisk ? "available" : "UNAVAILABLE")."\n";
    print "  * FILEDISK - the data is kept in a host file (common) : ".($canfiledisk ? "available" : "UNAVAILABLE")."\n";
    print "  * NETDISK - the data is accessed via the network (uncommon) : ".($cannetdisk ? "available" : "UNAVAILABLE")."\n";
    print "  * TMPDISK - the data is kept in memory and discarded (common) : ".($cantmpdisk ? "available" : "UNAVAILABLE")."\n";
    while (1) {
      print "Which option do you want for this device? {".join(", ",@disks)."} [] : ";
      $type = get_user("");
      my @test = grep {/^$type$/} @disks;
      last if $#test==0;
    }

    if ($type eq "filedisk" || $type eq "ramdisk") { 
      print "$type requires a file (.iso for example).  Do you have one? [y] : ";
      if (get_user("y") eq "y") { 
	while (1) { 
	  print "What is its path? [] : ";
	  $file = get_user("");
	  if (!(-e $file)) {
	    print "$file does not exist\n";
	    next;
	  }
	  if (system("cp $file $dir/$frontend\_$loc.dat")) { 
	    print "Unable to copy $file\n";
	    next;
	  }
          last;
	}
      } else {
	print "We will make one.  How big should it be in MB? [64] : ";
	$size = get_user("64");
	gen_image_file("$dir/$frontend\_$loc.dat",$size);
      }
      $attach="    <frontend tag=\"$frontend\">\n";
      if ($what eq "cd") { 
	$attach.="     <model>V3VEE CDROM</model>\n".
                 "     <type>CDROM</type>\n".$frontendblock;
	$cr->{havecd}=1;
      } else {
	$attach.="     <model>V3VEE HD</model>\n".
                 "     <type>HD</type>\n".$frontendblock;
	$cr->{havehd}=1;
      }
      $attach.="    </frontend>\n";

      if ($type eq "ramdisk") { 
	add_device($cr,"RAMDISK","$frontend\_$loc", undef, 
		   "    <file>$frontend\_$loc</file>\n".$attach);
	add_file($cr, "$frontend\_$loc", "$frontend\_$loc.dat");
      } else {
	add_device($cr,"FILEDISK","$frontend\_$loc", $what eq "hd" ? "writable=\"1\"" : undef, 
		   "    <path>$frontend\_$loc.dat</path>\n".$attach);
      }
      last;
    } else {
      print "$type is not currently supported\n";
      next;
    }
  }
}


sub do_generic {
  my ($cr, $pdir)=@_;

  $block = <<GENERIC1
    <ports> 
      <!-- DMA 1 registers -->
      <start>0x00</start>
      <end>0x07</end>
      <mode>PRINT_AND_IGNORE</mode>
    </ports>
    <ports>
      <!-- DMA 2 registers -->
      <start>0xc0</start>
      <end>0xc7</end>
      <mode>PRINT_AND_IGNORE</mode>
    </ports>
    <ports>
     <!-- DMA 1 page registers -->
     <start>0x81</start>
     <end>0x87</end>
     <mode>PRINT_AND_IGNORE</mode>
    </ports>
    <ports>
     <!-- DMA 2 page registers -->
     <start>0x88</start>
     <end>0x8f</end>
     <mode>PRINT_AND_IGNORE</mode>
    </ports>
    <ports>
      <!-- DMA 1 Misc Registers -->
      <start>0x08</start>
      <end>0x0f</end>
      <mode>PRINT_AND_IGNORE</mode>
    </ports>
    <ports>
     <!-- DMA 2 Misc Registers -->
     <start>0xd0</start>
     <end>0xde</end>
     <mode>PRINT_AND_IGNORE</mode>
    </ports>
    <ports>
     <!-- ISA PNP -->
     <start>0x274</start>
     <end>0x277</end>
     <mode>PRINT_AND_IGNORE</mode>
    </ports>
    <ports>
     <!-- ISA PNP -->
     <start>0x279</start>
     <end>0x279</end>
     <mode>PRINT_AND_IGNORE</mode>
    </ports>
    <ports>
     <!-- ISA PNP -->
     <start>0xa79</start>
     <end>0xa79</end>
     <mode>PRINT_AND_IGNORE</mode>
    </ports>
GENERIC1
;
  my @dev = find_devices_by_class($cr,"PARALLEL");
  if ($#dev<0) { 
    $block .= <<GENERIC2
    <ports>
     <!-- Parallel Port -->
     <start>0x378</start>
     <end>0x37f</end>
     <mode>PRINT_AND_IGNORE</mode>
    </ports>
GENERIC2
;
  }
  my @par = find_devices_by_class($cr,"SERIAL");
  if ($#par<0) { 
    $block .=<<GENERIC3
    <ports>
     <!-- Serial COM 1 -->
     <start>0x3f8</start>
     <end>0x3ff</end>
     <mode>PRINT_AND_IGNORE</mode>
    </ports>
    <ports>
     <!-- Serial COM 2 -->
     <start>0x2f8</start>
     <end>0x2ff</end>
     <mode>PRINT_AND_IGNORE</mode>
    </ports>
    <ports>
     <!-- Serial COM 3 -->
     <start>0x3e8</start>
     <end>0x3ef</end>
     <mode>PRINT_AND_IGNORE</mode>
    </ports>
    <ports>
    <!-- Serial COM 4 -->
     <start>0x2e8</start>
     <end>0x2ef</end>
     <mode>PRINT_AND_IGNORE</mode>
    </ports>
GENERIC3
;
  }

  do_device($cr, $pdir, "V3_CONFIG_GENERIC", "GENERIC", "generic", 1, undef, $block);
}

sub add_file {
  my ($cr, $name, $file) = @_;
  
  push @{$cr->{files}}, { name=>$name, file=>$file};

}

sub add_device {
  my ($cr, $class, $id, $optblob, $nestblob) = @_;

  push @{$cr->{devices}}, { class=>$class, id=>$id, opt=>$optblob, nest=>$nestblob };
}

sub find_devices_by_class {
  my ($cr,$c)=@_;
  return grep { $_->{class} eq $c } @{$cr->{devices}};
}

sub numa_setup {
  my $cr =shift;
  my $vnode;
  my $s="";

  if (!defined($cr->{numa})) { 
    return "";
  } else {
    $s.=" <mem_layout vnodes=\"".($#{$cr->{nodes}}+1)."\" >\n";
    foreach $vnode (@{$cr->{nodes}}) {
      $s.="   <region start_addr=\"".$vnode->{start}."\" end_addr=\"".$vnode->{end}."\" vnode=\"".$vnode->{vnode}."\" node=\"".$vnode->{pnode}."\" />\n";
    }
    $s.=" </mem_layout>\n";
    return $s;
  }
}

sub core_setup  {
  my $cr = shift;
  my $i;
  my $s="";
  
  
  $s.= " <cores count=\"".$cr->{numcores}."\">\n";
  if (!defined($cr->{numa})) { 
    $s.= "  <core />\n";
  } else {
    for ($i=0;$i<$cr->{numcores};$i++) { 
      $s.= "  <core target_cpu=\"".$cr->{"core$i"}{pcore}."\" vnode=\"".$cr->{"core$i"}{vnode}."\" />\n";
    }
  }
  $s.= " </cores>\n";
  
  return $s;
}

sub memory_setup
{
  my $cr=shift;

  return " <memory>".$cr->{mem}."</memory>\n";
}

sub paging_setup  {
  my $cr = shift;
  my $s="";
  
  $s.= " <paging mode=\"".$cr->{paging_mode}."\">\n";
  $s.= "  <large_pages>".$cr->{large_pages}."</large_pages>\n";
  $s.= "  <strategy>".$cr->{shadow_strategy}."</strategy>\n";
  $s.= " </paging>\n";
  
  return $s;
}

sub memmap_setup {
  my $cr = shift;

  return $cr->{memmap_block};
}

sub schedule_setup {
  my $cr = shift;

  return $cr->{schedule_hz_block};
}


sub perftune_setup  {
  my $cr=shift;
  my $s="";
  if (defined($cr->{perftune_block})) { 
    $s.=" <perftune>\n";
    $s.= $cr->{perftune_block};
    $s.=" </perftune>\n";
  }
  return $s;
}

sub extensions_setup  {
  my $cr=shift;
  my $s="";
  if (defined($cr->{extensions_block})) { 
    $s.=" <extensions>\n";
    $s.= $cr->{extensions_block};
    $s.=" </extensions>\n";
  }
  return $s;
}

sub swapping_setup {
  my $cr=shift;
  if (defined($cr->{swapping}) && $cr->{swapping} eq "y") { 
    return " <swapping enable=\"y\">\n  <allocated>".$cr->{swap_alloc}."</allocated>\n  <file>".$cr->{swap_file}."</file>\n  <strategy>".$cr->{swap_strat}."</strategy>\n </swapping>\n";
  } else {
    return " <!-- there is no swapping configuration, but you can add one manually -->\n";
  }
}
sub telemetry_setup  {
  my $cr=shift;
  return " <telemetry>".$cr->{telemetry}."</telemetry>\n";
}

sub file_setup { 
  my $cr=shift;
  my $cf;
  my $s="";

  if (!defined($cr->{files})) { 
    return " <!-- this configuration contains no files -->\n";
  } else {

    $s.=" <files>\n";
   
    foreach $cf (@{$cr->{files}}) {
      $s.="   <file id=\"".$cf->{name}."\" filename=\"".$cf->{file}."\" />\n";
    }
    $s.=" </files>\n";
    return $s;
  }
}

sub device_setup { 
  my $cr=shift;
  my $cd;
  my $s="";

  $s.=" <devices>\n";

  foreach $cd (@{$cr->{devices}}) {
    $s.="   <device class=\"".$cd->{class}."\" id=\"".$cd->{id}."\"";
    if (defined($cd->{opt})) { 
      $s.=" ".$cd->{opt};
    }
    if (!defined($cd->{nest})) { 
      $s.=" />\n";
    } else {
      $s.=" >\n";
      $s.=$cd->{nest};
      $s.="   </device>\n";
    }
  }

  $s.=" </devices>\n";

  return $s;

}



sub get_user {
  my $def = shift;
  
  my $inp = <STDIN>; chomp($inp);
  
  if ($inp eq "") { 
    return $def;
  } else {
    return $inp;
  }
}

sub get_kernel_feature {
  my $dir=shift;
  my $feature=shift;
  my $x;

  $x=`grep $feature= $dir/config-\`uname -r\``;

  if ($x=~/^\s*\#/) {
    return undef;
  } else {
    if ($x=~/\s*$feature=\s*(\S*)\s*$/) {
      return $1;
    } else {
      return undef;
    }
  }
}
  
sub get_palacios_core_feature {
  my $dir=shift;
  my $feature=shift;
  my $x;

  $x=`grep $feature= $dir/.config`;

  if ($x=~/^\s*\#/) {
    return undef;
  } else {
    if ($x=~/\s*$feature=\s*(\S*)\s*$/) {
      return $1;
    } else {
      return undef;
    }
  }
}

sub is_palacios_core_feature_enabled {
  my $out = get_palacios_core_feature(@_);
  return !defined($out) ? 0 : $out eq "y";
}


sub powerof2  {
  my $x = shift;
  my $exp;
  
  $exp = log($x) /log(2);

  return $exp==int($exp);
}


sub gen_image_file {
  my ($name, $size_mb) = @_;

  if (system("dd if=/dev/zero of=$name bs=1048576 count=$size_mb")) { 
    return -1;
  } else  {
    return 0;
  }
}
