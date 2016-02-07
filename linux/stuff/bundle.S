#define TIMEOUT		autostart after 5 seconds
#define CHECK_FILES	add 'Check media' entry

	.arch	i8086
	.code16
	.org	0
start:
	// stack segment setup
	cld
	movw	$0x9000, %di
	pushw	%di
	popw	%ss
	movw	%di, %sp

	// patch disk parameter table
	xorw	%ax, %ax
	movw	$0x78, %bx
	movw	%ax, %ds
	ldsw	(%bx), %si	
	pushw	%ss
	popw	%es
	movw	$64/2, %cx
	rep
	 stosw
	movb	$6, %cl
	pushw	%di
	rep
	 movsw
	movb	$63, %es:4-12(%di)
	movw	%cx, %ds
	popw	(%bx)
	movw	%es, 2(%bx)	

	// data segments setup
	movw	$0x7C0, %ax
	pushw	%ax
	popw	%ds
	pushw	%ds
	popw	%es

	// main loop
menustart:
	xorw	%bp, %bp
menudown:
	incw	%bp
menustartlp:
	movw	$3, %ax
	int	$0x10		// clear screen
	movb	$1, %ah
	movw	$0x1000, %cx
	int	$0x10		// clear cursor
	movw	$menu, %si
	call	puts
	call	putcr
	movw	%bp, %cx
menulp:
	movb	$' ', %bh
	lodsw
	loop	notcur
	xchgw	%ax, %di
	movb	$'>', %bh
notcur:
	movb	%bh, %al
	call	putcs
#ifdef CHECK_FILES
	lodsw		// CRC16
	lodsw		// sector count
#endif
	cmpw	%bx, (%si)
	jnc	menulp
#ifdef CHECK_FILES
	movw	$msgcrc, %si
	movb	$' ', %al
	loop	notcrc
	movb	$'>', %al
notcrc:
	call	putcs
#endif
menustartz:
#ifdef TIMEOUT
clock	= 0x46C
wait:
wait4key:
	pushw	%ds
	movw	$0, %ax
	movw	%ax, %ds
	movw	$clock, %si
#define DELAY 5
	movb	$257-(DELAY*182)/10, (%si)
waitkbd:
	movw	$0x10D, %ax		// test keyboard, timeout => CR
	cmpb	(%si), %ah
	je	waitdone
	int	$0x16
	jz	waitkbd
	cbw
	int	$0x16			// eat char
	movw	%si, wait4key+0x7C02	// disable timeout
waitdone:
	popw	%ds
#else
	xorb	%ax, %ax
	int	$0x16
#endif
	cmpb	$0x0D, %al	// CR ?
	je	doit
	cmpb	$0x48, %ah	// UP ?
	jne	isitdn
	decw	%bp
	jz	menudown
isitdn:
	incw	%cx
	cmpb	$0x50, %ah	// DN ?
	loope	menudown
	jmp	menustartlp

	.macro	tochs		// %di -> %cx, %dx & %bp=sector max
	movw	$64, %cx
	movw	$0x200, %bx
sectlp:
	movw	$0x201,	%ax
	movb	%ch, %dh
	decw	%cx
	int	$0x13
	jc	sectlp
	movw	%cx, %bp
	movw	%di, %ax
	div	%cl		// 32 Mb & 255 tracks max
	movb	%ah, %cl	// sector
	incb	%cl
	shrb	$1, %al		// C = head, AL = cylinder
	adcb	%dh, %dh
	movb	%al, %ch
	.endm

doit:
#ifdef CHECK_FILES
	jcxz	docrc
	call	getsectors
#else
	tochs		// %di -> %cx, %dx & %bp=sector max
#endif
	pushw	%cx
	movw	$0x201,	%ax
	int	$0x13
	popw	%cx
	jc	menustart

	// scan boot code
	movw	%bx, %di
scanboot:
	incw	%di
	cmpw	$0x5897, -3(%di)	// xchgw %ax, %di; popw	%ax
	jne	scanboot
	cmpw	$0xE841, -1(%di)	// incw %cx ; call ...
	jne	scanboot
	pushw	%ds
	pushw	%di
	movb	0x1F1(%bx), %al		// setup size
	pushw	%ss
	popw	%ds
	pushw	%ss
	popw	%es
	xorw	%di, %di
	xchgw	%ax, %di		// ax = limits = 0
	xorw	%bx, %bx		// to %es:%bx = 9000:0000
	incw	%di			// Add bootsector, Clear Z
	lret				// Read from %dx, %cx

#ifdef CHECK_FILES
docrc:
	movw	$menu, %si
skiptitle:
	lodsb
	orb	%al, %al
	jnz	skiptitle
nextchk:
	lodsw			// sector offset
	xchgw	%ax, %di
	movw	%di, %cx
	movw	$1, %bp
	jcxz	menustartz
	call	puts		// menu entry
	call	getsectors
	lodsw
	xchgw	%ax, %di	// crc
	movw	$0x201,	%ax
	int	$0x13
	lodsw			// sector count
	pushw	%si
	jc	chkfail
	xchgw	%ax, %si
chksector:
	subw	(%bx), %di
	incw	%bx
	incw	%bx
	cmpb	$4, %bh
	jne	chksector
	movb	$2, %bh
	decw	%si
	je	chkend
	movw	%bp, %ax
	incw	%cx
	cmpb	%al, %cl
	jle	rdit
	movb	$1, %cl
	xorb	%cl, %dh
	jne	rdit
	incb	%ch
rdit:
	movw	$0x201, %ax
	int	$0x13
	jnc	chksector
chkend:
	movw	$msgok, %si
	orw	%di, %di
	je	chkok
chkfail:
	movw	$msgko, %si
chkok:
	call	puts
	popw	%si
	jmp	nextchk

getsectors:
	tochs		// %di -> %cx, %dx & %bp=sector max
return:
	ret
#endif

putcr:
	movb	$10, %al
putlf:
	xorb	$10^13, %al
putcs:
	movw	$7, %bx
	movb	$0xE, %ah
	int	$0x10
	cmpb	$13, %al
	jz	putlf
	jc	return
puts:
	lodsb
	orb	%al, %al
	jnz	putcs
	jmp	putcr
#ifndef CHECK_FILES
return:
	ret
#endif

#ifdef CHECK_FILES
msgok:
	.asciz	" OK"
msgko:
	.asciz	" Broken"
msgcrc:	
	.asciz	"Check media"		// used to detect CHECK_FILES
#endif
menu:

	.org	0x1F1
setupsz:
	.byte	0
rootflags:
	.word	menu
syssz:
	.long	0	// updated by bundle
ramsize:
	.ascii	"SliTaz"
//	.word	0
//vidmode:
//	.word	0
//rootdev:
//	.word	0
bootflag:
	.word	0xAA55
