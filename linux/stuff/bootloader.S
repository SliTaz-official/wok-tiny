BOOTSEG		= 0x07C0		/* original address of boot-sector */
SYSSEG		= 0x1000		/* historical load address >> 4 */
INITSEG		= 0x9000		/* boot address >> 4 */
SETUPSEG	= 0x9020		/* setup address >> 4 */
ASK_VGA		= -3

#ifndef SVGA_MODE
#define SVGA_MODE ASK_VGA
#endif

#ifndef RAMDISK
#define RAMDISK 0
#endif

#ifndef ROOT_RDONLY
#define ROOT_RDONLY 1
#endif

/* Assume protocol 2.00+ (kernel >= 1.3.73) */

/* basic support: zImage or bzImage, floppy parameters table patch, */
/* any sectors/track count (720K, 1.2M, 1.44M floppy or 1.68M ...), */
/* show progress (.), show errors (-) */

/* extra feature set */
#define EXE_SUPPORT		real mode dos .exe file support
#define EXE_CMDLINE		kernel >= 2.4
// #define FLOPPY_CMDLINE	kernel >= 2.4
// #define OLDCMDLINE		kernel  < 2.4
#define DISPLAY_VERSION		display version string
#define MORETHAN16M		up to 4Gb RAM, not 16Mb
#define KEYBOARDLESS_SUPPORT	scan floppy swap each 5 seconds
// #define FAT12_SUPPORT	will format the floppy free space in FAT 12
// #define CHECK_REALMODE	exe dont crash when started in vm86
#define MULTI_FLOPPY		Everything may dont fit in a single floppy
// #define EDIT_CMDLINE		Wait 5 seconds for the first key to edit it
// #define MOVE_CMDLINE
#define INITRD_SUPPORT
// #define INITRD_AUTOADDR	Hole in 16Mb..32Mb
// #define MULTI_INITRD		Russian dolls
// #define README_SUPPORT
// #define COUNTER		Show floppy number
#define LABEL "Tiny"

/* remove from basic features */
// #define EXE_ONLY		remove floppy code
// #define NO_FLOPPY_TABLE_PATCH	remove floppy parameter table patch
// #define NO_OUTPUT		remove output code

	//.arch	i386,nojumps
	.code16
	.org	0

#ifdef NO_OUTPUT
# undef DISPLAY_VERSION
# undef README_SUPPORT
# undef FLOPPY_CMDLINE
# undef COUNTER
#endif

bootsect_start:

cur_initrd_size_ofs	= 494
ramdisk_image_ofs	= 0x218
ramdisk_image	=	bootsect_start+ramdisk_image_ofs
ramdisk_size_ofs	= 0x21C
ramdisk_size	=	bootsect_start+ramdisk_size_ofs
cmd_line_ptr_ofs	= 0x228
cmd_line_ptr	=	bootsect_start+cmd_line_ptr_ofs
setup_sects	=	bootsect_start+497
syssize		=	bootsect_start+500
boot_flag_ofs	= 510
boot_flag	=	bootsect_start+boot_flag_ofs


stacktop	= 0x9E00		# in 0x8000 .. 0xA000
#ifdef NO_FLOPPY_TABLE_PATCH
zeroed		= 48+8			# gdt + zeroed registers
#else
zeroed		= 48+10			# gdt + zeroed registers
#endif
.macro	INIT_REGS
	movw	$stacktop-zeroed, %di	# stacktop is an arbitrary value >=
					# length of bootsect + length of
					# setup + room for stack;
					# 12 is disk parm size.
	movw	$INITSEG, %ax
	movw	%ax, %ss		# %ss contain INITSEG
	movw	%di, %sp		# put stack at INITSEG:stacktop-...
	movw	%ax, %es		# %es = %ss = INITSEG
	cbw				# %ax = 0
	cld
#ifdef EXE_CMDLINE
	movw	$zeroed+1, %cx		# clear gdt + offset, %ds, limits, cmdline=""
	rep
	stosb
	decw	%di
#else
	movw	$zeroed/2, %cx		# clear gdt + offset, %ds, limits
	rep
	stosw
#endif
	popw	%bx			# offset = 0
.endm

#ifdef FAT12_SUPPORT
	jmp	fdstart
	nop
	.ascii	"SLITAZ  "
	.word	512			// 0B: bytes per sector
	.byte	1			// 0D: sectors per cluster
	.word	2880			// 0E: reserved seectors
	.byte	2			// 10: FAT number
	.word	64			// 11: root entries 4x 16
	.word	2880			// 13: total sectors
	.byte	0xF0			// 15: media id (or F9)
#endif

#ifdef EXE_SUPPORT
#define CODESZ		0x8000
#define EXEADRS(x)	x+0xE0
	decw	%bp			// Magic number: MZ
	popw	%dx
#ifdef EXE_ONLY
	.word	512			// Bytes on last page of file
#else
	jmp	fdstart			// Bytes on last page of file
#endif
	.word	(CODESZ+511)/512	// Pages in file
	.word	0			// Relocations
	.word	2			// Size of header in paragraphs
	.word	4096			// Minimum extra paragraphs needed
	.word	-1			// Maximum extra paragraphs needed
	.word	(CODESZ+15)/16		// Initial (relative) SS value
	.word	stacktop+4		// Initial SP value (+callf)
	.word	0			// Checksum
	.word	EXEADRS(comstart)	// Initial IP value
	.word	0xFFF0			// Initial (relative) CS value
#if defined(EXE_ONLY) || !defined(MULTI_FLOPPY) || defined(COUNTER)
//	.word	0x001C			// File address of relocation table
//	.word	0,0,0			// Overlay number
	.ascii	"(SliTaz)"
#else
swap_floppy:
	.ascii	"Next!"
	.byte	7,13,0			# swap detection needs 13, 0
#endif
#ifdef OLDCMDLINE
# ifdef FLOPPY_CMDLINE
	.word	0			# 0xA33F
	.word	0			# stacktop
# else
	.word	0xA33F
	.word	stacktop
# endif
#endif
#ifndef EXE_ONLY
fdstart:
	pushw	%dx
#endif
#endif
 
LOADSEG		= 0x8000		# 0x1000 multiple, up to 512K zImage
LOADSZ		= 0x10000

#if defined(EXE_SUPPORT) || defined(EXE_ONLY)
A20BUFFER	= 0x68000		# a20 gate / himem.sys support
#define USEA20BUFFER			# Does not break zImage support
#endif
 
#ifndef EXE_ONLY
# bootsect_start:
#ifdef EXE_SUPPORT
	call	initregs
	cwd				# floppy = head = 0
#else
	INIT_REGS
#endif
	popw	%ds			# %ds = 0
	movb	setup_sects+0x7C00, %al	# read bootsector + setup
	incw	%ax			# %ax = setup_sects+bootsect
	popw	%fs			# %fs = 0

# Many BIOS's default disk parameter tables will not recognize
# multi-sector reads beyond the maximum sector number specified
# in the default diskette parameter tables - this may mean 7
# sectors in some cases.
#
# Since single sector reads are slow and out of the question,
# we must take care of this by creating new parameter tables
# (for the first disk) in RAM.  We can set the maximum sector
# count to 36 - the most we will encounter on an ED 2.88.  
#
# High doesn't hurt.  Low does.  Let's use the max: 63

	cli
#ifdef NO_FLOPPY_TABLE_PATCH
	xchg	%ax, %di		# sector count
	popw	%ax			# limits = 0
	incw	%cx			# cylinder 0, sector 1, clear Z
	call	read_first_sectors	# read setup
# ifdef	FLOPPY_CMDLINE
	movw	$0, %si			# patched by installer (7C22)
skipcmdline:
#define cmd_line_ptr	0x22
# endif
#else
	ldsw	0x78(%bx), %si		# %ds:%bx+0x78 is parameter table address
	pushw	%es
	pushw	%di
# ifdef	FLOPPY_CMDLINE
	movw	$0, %bp			# patched by installer (7C22)
skipcmdline:
#define cmd_line_ptr	0x22
# endif
	movb	$6, %cl			# copy 12 bytes
	rep				# don't worry about cld
	  movsw				# already done above
	pushw	%ss
	popw	%ds			# now %ds = %es = %ss = INITSEG
	popl	%fs:0x78(%bx)		# update parameter table address
	movb	$63, 0x4-12(%di)	# patch sector count, %di = stacktop

	xchg	%ax, %di		# sector count
	popw	%ax			# limits = 0
	incw	%cx			# cylinder 0, sector 1, clear Z
	call	read_first_sectors	# read setup
#endif
#ifdef	README_SUPPORT
	xorw	%si, %si
	orw	readme, %si
	jz	readmeend
readmeloop:
	call	puts
	jz	readmeend
	call	wait4key
	cmpb	$27, %al
	jne	readmeloop
readmeend:
#endif
#endif
loadsys:
	movw	$0x200,%si
type_of_loader	=	0x10
loadflags	=	0x11
heap_end_ptr	=	0x24
	orw	$0x8020, type_of_loader(%si) # loader type = 0x20 = bootsect-loader
	movb	$(stacktop-0x300)/256, heap_end_ptr+1(%si)
#ifdef DISPLAY_VERSION
	call	puts_version		# show which kernel we are loading
#endif

#ifdef	FLOPPY_CMDLINE
# The cmdline can be entered and modifed at boot time.
# Only characters before the cursor are passed to the kernel.

	xorw	%si, %si
	orw	cmd_line_ptr-7(%bx), %si
	jz	nocmdline
#ifdef OLDCMDLINE
	movw	$0xA33F, cmd_line_ptr-2-7(%bx)
#endif
	call	puts
#ifdef	EDIT_CMDLINE
cmdlp:
	movb	$0x20, %al		# clear end of line
cmdlpz:
	call	putc			#  with Space
	subb	$0x18, %al		#   and BackSpace
	jnc	cmdlpz
	decw	%si
cmdget:
#ifdef KEYBOARDLESS_SUPPORT
	call	wait4key
#else
	int	$0x16
	cbw				# %ah = 0, get keyboard character
#endif
	cmpb	$8, %al			# BackSpace ?
	je	cmdbs
	movb	%al, (%si)		# store char
	lodsw				# %si += 2
cmdbs:
	cmpw	%si, cmd_line_ptr-7(%bx)
	je	cmdget
	call	putc
	cmpb	$10, %al		# Enter/linefeed ?
	jne	cmdlp
	movb	%bh,-2(%si)		# set end of string and remove CR
endcmdline:
#endif
#ifdef MOVE_CMDLINE
	pushw	%ss
	popw	%es
	movw	$0x8000, %di
	movw	%di, %si
	xchgw	%si, cmd_line_ptr-7(%bx)
	movb	$0x2, %ch
	rep
	  movsb
#endif
nocmdline:
#endif

# This routine loads the system at address LOADSEG, making sure
# no 64kB boundaries are crossed. We try to load it as fast as
# possible, loading whole tracks whenever we can.

.macro	autoaddr base
	movb	$0x88, %ah
	int	$0x15
	//jc	NeedMoreRAM			# error code 80 or 86
	cmpw	$0xB000, %ax			# more than 45M ?
	jb	NeedMoreRAM
	movb	%ch, bootsect_dst_base_hi(%si)	# initramfs @ 32M
	movb	%ch, ramdisk_image_ofs+3-\base
NeedMoreRAM:
.endm

bootsect_src_limit	= 16
bootsect_dst_limit	= 24
bootsect_src_base	= 18
bootsect_dst_base	= 26		# bits  0..23
bootsect_dst_base_hi	= 31		# bits 24..31
	popw	%bx			# clear %bx
	movw	%sp, %si		# for bootsect_gdt
init_gdt:
	decw	bootsect_src_limit(%bx,%si)	# max 64Kb
	movw	$0x9300+(LOADSEG/0x1000), bootsect_src_base+2(%bx,%si)
	xorb	$bootsect_dst_limit-bootsect_src_limit, %bl
	jne	init_gdt
#ifdef INITRD_SUPPORT
	movw	$syssize, %bx
	movb	$5, %cl
code32_start	=	0x214
	movw	code32_start+1, %ax		# destination = 0x00100000 or 0x00010000
initrdlp:
	movl	(%bx), %ebx
	decl	%ebx
	shrl	%cl, %ebx
#else
code32_start	=	0x214
	movw	code32_start+1, %ax		# destination = 0x00100000 or 0x00010000
	movl	syssize, %ebx
	decl	%ebx
	shrl	$5, %ebx
#endif
#ifdef MORETHAN16M
	incl	%ebx
#else
	incw	%bx
#endif
#ifdef USEA20BUFFER
	movw	$0x00100000>>8, %di
#endif
syslp:
#ifdef USEA20BUFFER
	cmpw	%ax, %di
	jne	nota20
	xorw	$(0x00100000+A20BUFFER)>>8, %ax
nota20:
#endif
	movw	%ax, bootsect_dst_base+1(%si)
#ifdef MORETHAN16M
	movl	$LOADSZ/512, %edi	# size in sectors
	subl	%edi, %ebx
#else
	movw	$LOADSZ/512, %di	# size in sectors
	subw	%di, %bx
#endif
	pushf
	jnc	not_last
	addw	%bx, %di
not_last:
#ifdef MULTI_INITRD
	pushw	%di
#endif
	pushw	%ax
	pushw	%bx
	pushw	%si
	xorw	%bx,%bx
	pushw	$LOADSEG
	popw	%es
#ifdef EXE_ONLY
	call	read_sectors_dos
#else
patchcall:
	call	read_sectors		# update %bp
#endif
	popw	%si
	popw	%bx
	movw	%es, %cx		# word count = LOADSZ/2 (= LOADSEG)
	movb	$0x87, %ah
	pushw	%ss
	popw	%es			# restore es
	int	$0x15			# max 16M, maybe more...
	popw	%ax
#ifdef MULTI_INITRD
	popw	%di
	shlw	$1,%di			# sectors to pages
	addw	%di, %ax
#ifdef MORETHAN16M
	adcb	%cl, bootsect_dst_base_hi(%si)	# breaks 16M limit ?
#endif
#else
#ifdef MORETHAN16M
	addw	$0x100, %ax		# next dest (ax+=LOADSZ/256)
	adcb	%cl, bootsect_dst_base_hi(%si)	# breaks 16M limit ?
#else
	incb	%ah			# next dest (ax+=LOADSZ/256)
#endif
#endif
#ifdef USEA20BUFFER
	movw	$(LOADSZ+A20BUFFER)>>8, %di
#endif
	popf
	ja	syslp
#ifdef INITRD_SUPPORT
initrdlp2:
#ifdef INITRD_AUTOADDR
	movw	$0x209, %cx
#else
	movb	$9, %cl
#endif
#ifdef MULTI_INITRD
	movw	$cur_initrd_size_ofs, %di
	movw	(%di), %bx
	addw	$4, (%di)
	shrw	%cl, boot_flag_ofs-cur_initrd_size_ofs(%di)
	je	nextInitrd	
	orw	%bx, %bx
	je	bootit			# no initrd
# ifdef INITRD_AUTOADDR
	autoaddr	cur_initrd_size_ofs(%di)
# endif
	movw	ramdisk_image+1,%ax
	jmp	initrdlp
nextInitrd:
	pushw	%bx
	movl	-4(%bx), %ebx
	addl	%ebx, ramdisk_size_ofs-cur_initrd_size_ofs(%di)
	movb	$swap_floppy2-0x100, %cs:dpy_swap_floppy-2+0x7C00
	popw	%bx
	cmpb	2(%di), %bl
	jb	initrdlp
#else
	movw	$ramdisk_size, %bx
#ifdef MORETHAN16M
	cmpb	%cl, ramdisk_image+2-ramdisk_size(%bx)
	jb	bootit
# ifdef INITRD_AUTOADDR
	autoaddr	ramdisk_size_ofs(%bx)
# endif
	movw	ramdisk_image+1,%ax
	shrw	%cl, boot_flag-ramdisk_size(%bx)
	jne	initrdlp
#else
	movw	ramdisk_image+1,%ax
	cmpw	%ax, bootsect_dst_base+1(%si)
	jb	initrdlp
#endif
#endif
bootit:
#ifdef USEA20BUFFER
#ifdef MORETHAN16M
#ifdef INITRD_SUPPORT
	movb	%al, bootsect_dst_base_hi(%si)		// assume @initrd 64k aligned
	//movb	$0, bootsect_dst_base_hi(%si)
#else
	movb	%cl, bootsect_dst_base_hi(%si)
#endif
#endif
	movb	$0x10, bootsect_dst_base+2(%si)		// assume @initrd 64k aligned
	//movw	$0x1000, bootsect_dst_base+1(%si)		// assume @initrd page aligned
	movw	$A20BUFFER/0x100, bootsect_src_base+1(%si)
	movb	$0x87, %ah
	int	$0x15
#endif
#endif
#ifdef MULTI_INITRD
        jcxz	read_sectorslp
#endif

# This procedure turns off the floppy drive motor, so
# that we enter the kernel in a known state, and
# don't have to worry about it later.

kill_motor:
#ifdef USEA20BUFFER
	cwd
#else
	xchgw	%ax, %di		# reset FDC (%di < 128)
#endif
	int	$0x13

# After that (everything loaded), we jump to the setup-routine
# loaded directly after the bootblock:
# Segments are as follows: %ds = %ss = INITSEG

	ljmp	$SETUPSEG, $0

# read_sectors reads %di sectors into %es:0 buffer.
# %es:0 is updated to the next memory location.
# First, sectors are read sector by sector until
# sector per track count is known. Then they are
# read track by track.
# Assume no error on first track.

#ifndef EXE_ONLY

# 720KB 800KB 880KB 1.04MB 1.12MB 1.2MB 1.44MB 1.6MB 1.68MB 1.76MB
# 1.84MB 1.92MB 2.88MB 3.12MB 3.20MB 3.52MB 3.84MB support
# do not support 820KB 830KB 1.48MB 1.49MB 1.72MB 1.74MB
#define FLOPPY_CYLINDERS	80
# do not support 360KB 410KB 420KB
#define FLOPPY_HEADS		2

#if defined(MULTI_FLOPPY) && defined(COUNTER)
.macro	putsmsg
	movw	$msgdigit+1-msg, %bx
nextdigit:
	andb	$0xF0, (%bx,%si)
	decw	%bx
	incb	(%bx,%si)
	cmpb	$'9', (%bx,%si)
	ja	nextdigit
	call	puts
.endm
#else
.macro	putsmsg
	call	puts
.endm
#endif

check_limits:
        cmpb    %cl, %al		# max sector known ?
        jbe	next_head		#   no -> store it
        #.byte	0xd6	# SALC		# sector by sector
        movb	$0, %al			# sector by sector
	pushaw
        int     $0x13			# reset controler
#ifndef NO_OUTPUT
	stc
	call	putcdot			# print '-'
#endif
read_sectorslp:
	popaw
bdendlp:
	pushw	%dx			# some bios break dx...
        pushw   %ax			# limits
	subb	%cl, %al		# sectors remaining in track
	ja	tolastsect
	movb	$1, %al			# 1 sector mini
tolastsect:
	cmpw	%di, %ax
	jb	more1trk
	movw	%di, %ax		# sectors to read
more1trk:
	pushw	%ax			# save context
	movb	$2, %ah			# cmd: read chs
        int     $0x13
	popw	%bp			# save %ax
        popw    %ax			# limits
	popw	%dx
	jc	check_limits
	xchgw	%ax, %bp
	addw	%ax,%cx			# next sector
	movw	%cx, %gs
	addb	%al,%bh
	addb	%al,%bh			# next location
	subw	%ax,%di			# update sector counter
	jz	putcdot
read_sectors:
	movw	%gs, %cx
#   al is last sector+1
#   ah is 0
	xchgw	%ax, %bp
        cmpb    %al,%cl			# reach sector limit ?
        jne     bdendlp
next_head:
        movb    %cl,%al
        movb    $1, %cl			# first sector
inc_head:
        xorb    %cl, %dh		# next head
        jne	bdendlp			# reach head limit ?
        incb    %ch			# next cylinder
read_first_sectors:
#ifndef MULTI_FLOPPY
	jmp	bdendlp
#else
        cmpb    $FLOPPY_CYLINDERS,%ch	# reach cylinder limit ?
        jne	bdendlp
next_floppy:
	movb	$0,%ch			# first cylinder
	pushaw
	movw	$swap_floppy,%si
dpy_swap_floppy:
#ifdef KEYBOARDLESS_SUPPORT
	pushw	%bx
# ifndef NO_OUTPUT
	putsmsg
# endif
	popw	%bx
	movw	%si, %bp
waitfloppy:
	call	wait
	jne	waitfloppydone
#ifdef MULTI_INITRD
	decb	(%si)			# max_timeouts	
gobootit:
	//movw	ramdisk_size+2-max_timeouts(%si), %cx
	.byte	0x8B, 0x4C, ramdisk_size+2-max_timeouts
	jz	bootit
#endif
	pushw	%dx			# some bios break dx...
	cbw
	int	$0x13			# reset FDC
	movw	$0x201,%ax
	int	$0x13			# read first sector
	popw	%dx
	rclb	$1,%ah			# floppy changed 06=>0D no error 00
	cmpb	-2(%bp), %ah		# 0D then 00
	jne	waitfloppy		# no => try again
	incw	%bp
	decw	%ax			# was 0001 ?
	jne	waitfloppy
waitfloppydone:
#else
# ifndef NO_OUTPUT
	putsmsg
# endif
	cbw				# %ah = 0, get keyboard character
	int	$0x16
#endif
#ifdef MULTI_INITRD
	orb	$0x20, %al
	cmp	$'b', %al
        jz	gobootit
#endif
        jmp	read_sectorslp
#endif
#endif

#ifdef EXE_SUPPORT
read_sectors_dos:
	xorw	%dx, %dx	// write to %ds:%dx, not %es:%bx
	call	read_sectors_dosz
read_sectors_dosz:
	pushw	%es
	popw	%ds
	movb	$0x3F, %ah	// read
	movw	%di, %cx
	shlw	$8, %cx		// byte count / 2
	movw	%bp, %bx
	int	$0x21
	xchgw	%ax, %dx
	pushw	%ss
	popw	%ds
#endif

putcdot:
#ifndef NO_OUTPUT
	movb	$'.'+3, %al	// . = success, - = failure
putclf:
	sbbb	$3, %al
putc:
	movb	$0xe, %ah
	movw	$7, %bx			#   one dot each 64k
 	int	$0x10
	cmp	$0xd, %al		# CR ?
	je	putclf
#endif
dosexit:
	ret

#ifdef KEYBOARDLESS_SUPPORT
clock	= 0x46C
wait:
wait4key:
	movw	$clock, %di
#define DELAY 5
	movb	$257-(DELAY*182)/10, %fs:(%di)
waitkbd:
	movw	$0x10D, %ax		# test keyboard, timeout => CR
	cmpb	%fs:(%di),%ah
	je	waitdone
	int	$0x16
	jz	waitkbd
	cbw
	int	$0x16			# eat char
	movw	%di, %fs		# disable timeout
	incw	%di			# clear Z
waitdone:
	ret
#endif

#ifdef EXE_SUPPORT
comstart:
#ifndef EXE_ONLY
	call	initregs
#else
	INIT_REGS
#endif
	movb	EXEADRS(setup_sects), %al	# read bootsector + setup
	incw	%ax
#ifdef EXE_CMDLINE
	movw	$0x80, %si
	movb	(%si), %cl
	incw	%si
# if defined(OLDCMDLINE) && defined(FLOPPY_CMDLINE)
	jcxz	nocmdline
	movw	%di, EXEADRS(0x22)
	movw	$0xA33F, 0x7F(%si)
# endif
	rep
	  movsb
nocmdline:
	xchgw	%ax, %di
# if defined(HELP) && defined(DISPLAY_VERSION)
	cmpb	$'?', -1(%si)
	movw	$EXEADRS(0x200), %si
	je	puts_version
# endif
#else
	xchgw	%ax, %di
#endif
#ifdef CHECK_REALMODE
	smsww	%ax
	andb	$1, %al
# if defined(HELP) && defined(DISPLAY_VERSION)
	jne	puts_version			// real mode only...
# else
	jne	dosexit				// real mode only...
# endif
	movb	$0x3D, %ah	// open, access = RO
#else
	movw	$0x3D00, %ax	// open, access = RO
#endif
	movw	0x2C(%bx), %ds	// DOS 3.0+
loop1:
	incw	%bx
	cmpw	%cx, (%bx)
	jne	loop1
	leaw	4(%bx), %dx 	// %ds:%dx filename
	int	$0x21
	jc	dosexit
	xchgw	%ax, %bp	// fd
	call	read_sectors_dos	// update %ds
#ifndef EXE_ONLY
	addb	$read_sectors_dos-read_sectors, patchcall+1
#endif
#ifdef EXE_CMDLINE
# ifdef OLDCMDLINE
	movw	$0x202, %bx
	cmpw	%bx, 0x206-0x202(%bx)	# new cmdline for version >= 0x202
	jb	oldcmdline
	movw	$INITSEG/16+stacktop/256, cmd_line_ptr+1-0x202(%bx)
# else
	movw	$INITSEG/16+stacktop/256, cmd_line_ptr+1
# endif
oldcmdline:
#endif
//	ljmp	$INITSEG, $loadsys
	pushw	%ds
	.byte	0x6A, loadsys-bootsect_start	# pushw	$loadsys-bootsect_start
	lretw
#endif
#define kernel_version_offset	0xE
#ifdef DISPLAY_VERSION
puts_version:
	addw	kernel_version_offset(%si),%si	# starting protocol 2.00, Kernel 1.3.73
#endif
#if defined(DISPLAY_VERSION) || defined(README_SUPPORT) || defined(FLOPPY_CMDLINE) || defined(MULTI_FLOPPY)
# ifndef NO_OUTPUT
puts:
	movb	$0xd, %al		# CR
putcs:
	call	putc
	lodsb
	cmpb	$0, %al			# end of string is any byte <= 0
	jg	putcs
	ret	
# endif
#endif

#if defined(MULTI_FLOPPY) && !defined(EXE_ONLY)
initregs:
	popw	%si
	INIT_REGS
	pushw	%si			# use new stack
	ret
#endif


#if defined(MULTI_FLOPPY) && !defined(EXE_SUPPORT)
#ifdef MULTI_INITRD
swap_floppy2:
	.ascii	"B or "
#endif
swap_floppy:
#ifdef COUNTER
msg:
	.ascii	"Put disk 00"
msgdigit:
	.ascii	"1, press Enter."
#else
	.ascii	"Next!"
#endif
	.byte	7,13,0			# swap detection needs 13, 0
#ifdef MULTI_INITRD
max_timeouts:
	.byte	20
table:
	.org	cur_initrd_size_ofs
cur_initrd_size:
	.word	table
	.byte	table+4-256
#endif
#endif
#ifdef	README_SUPPORT
	.org	0x1EF
readme:
	.word	0
#endif
#ifdef LABEL
	.ascii LABEL
#endif
	.org	0x1F1

#ifdef MULTI_INITRD
	.org	0x400
	
	orw	$0x8020, type_of_loader(%si) # loader type = 0x20 = bootsect-loader
	pushal
	
	movw	$10+16, %cx
fillbuf:
	pushw	$0
	loop	fillbuf
	popal			// clear regiters
maploop:
	movw	%sp, %di	// %es = %ss
	movb	$20, %cl
	movw	$0xE820, %ax
	movl	$0x534d4150, %edx
	int	$0x15
	sbbl	%eax, %edx
	jne	mapdone
	decw	16(%di)	
	jne	notram
	addw	8+2(%di), %bp
notram:
	orw	%bx, %bx
	jnz	maploop
mapdone:
	addw	$20, %sp
	shrw	$20-16,%bp
	jnz	mapdone2
	movb	$0x88, %ah
	int	$0x15
	xchgw	%ax, %bp
	shrw	$10, %bp
mapdone2:
	incw	%bp
// %bp : nb Mb	
	call	here
here:
	popw	%di
	movw	$0x1EE, %si
	lodsw
sizeloop:
	scasw			// %di += 2
	addw	$4, %ax
	cmpb	%al, (%si)	
	jbe	sizedone
	cmpw	%bp, sizes-here(%di)
	jbe	sizeloop
	movb	%al, (%si)
sizedone:
	popal
	lret			// need %si
sizes:

#endif
