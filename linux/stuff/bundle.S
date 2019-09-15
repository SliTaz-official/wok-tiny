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
	xorw	%cx, %cx
	pushw	%cx			// bootloader may want to pull 0
	movw	$0x78, %bx
	movw	%cx, %ds
	ldsw	(%bx), %si	
	pushw	%ss
	popw	%es
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
	.macro	entry
	movb	$' ', %bl
	lodsw
	loop	notcur
	xchgw	%ax, %di
	movb	$'>', %bl
notcur:
	xchgw	%ax, %bx
	.endm
#ifdef CHECK_FILES
	call	putentry
	lodsw		// CRC16
	lodsw		// sector count
#else
	entry
	call	putcs
#endif
	cmpw	$0, (%si)
	jne	menulp
#ifdef CHECK_FILES
	movw	$msgcrc-2, %si
	call	putentry
#endif
menustartz:
	.macro	waitkbdcode
#ifdef TIMEOUT
clock	= 0x46C
wait:
wait4key:
	pushw	%ds
	xorw	%ax, %ax
	movw	%ax, %ds
	movw	$clock, %si
#define DELAY 5
	movb	$257-(DELAY*182)/10, (%si)
waitkbd:
	movw	$0x10D, %ax		// test keyboard, timeout => CR
	cmpb	(%si), %ah
clock_patch:
	je	waitdone
	int	$0x16
	jz	waitkbd
	cbw
	int	$0x16			// eat char
	movb	$0xA8, clock_patch+0x7C00	// disable timeout
waitdone:
	popw	%ds
#else
	xorb	%ax, %ax
	int	$0x16
#endif
	.endm
#ifdef CHECK_FILES
	call	wait4kbd
#else
	waitkbdcode
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

#ifdef CHECK_FILES
toeos:
	lodsb
	orb	%al, %al
	jnz	toeos
	lodsw			// crc, count
	lodsw
	cmpw	$0, (%si)
	jne	nextchk
	call	wait4kbd
	jmp	start
#endif

	.macro	tochs		// %di -> %cx, %dx & %bp=sector max
	movw	$64, %cx
sectlp:
	movb	%ch, %dh
	decw	%cx
#define BUFFER	0x200
#ifdef CHECK_FILES
	call	readsector
#else
	movw	$BUFFER, %bx
	movw	$0x201,	%ax
	int	$0x13
#endif
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
	call	readsector2
#else
	tochs		// %di -> %cx, %dx & %bp=sector max
	movw	$0x201,	%ax
	int	$0x13
#endif
	jc	menustart

	// scan boot code
scanboot:
	incw	%bx
	cmpw	$0x5897, -3(%bx)	// xchgw %ax, %di; popw	%ax
	jne	scanboot
	cmpw	$0xE841, -1(%bx)	// incw %cx ; call ...
	jne	scanboot
found:
	pushw	%ds
	pushw	%bx
	cli
	movb	0x1F1+BUFFER, %al	// setup size
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
nextchklp:
	pushw	%si		// start of menu
nextchk:
	lodsw			// sector offset
	cmpw	%ax, %di	// next sector offset
	jne	toeos
	call	puts		// menu entry
	call	getsectors	// %di -> %cx, %dx & %bp=sector max
	lodsw
	addw	(%si), %di
	pushw	%di		// next sector offset
	xchgw	%ax, %di	// crc
	lodsw			// sector count
	xchgw	%ax, %si
chksector:
	call	readsector
	jc	chkfail
chksectorz:
	subw	(%bx), %di
	incw	%bx
	incw	%bx
	cmpb	$4, %bh
	jne	chksectorz
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
	cmp	$80, %ch
	jb	rdit
	push	%si
	mov	$msgnext, %si
	call	puts
	call	wait4kbd
	pop	%si
	mov	$0, %ch
rdit:
	jmp	chksector
chkend:
	movw	$msgok, %si
	orw	%di, %di
	je	chkok
chkfail:
	movw	$msgko, %si
chkok:
	call	puts
	popw	%di		// next sector offset
	popw	%si		// start of menu
	jmp	nextchklp

readsector:
	movw	$BUFFER, %bx
readsector2:
	movw	$0x201,	%ax
	int	$0x13
	ret

getsectors:
	tochs		// %di -> %cx, %dx & %bp=sector max
	ret

wait4kbd:
	waitkbdcode
	ret

putentry:
	entry
	jmp	putcs
#endif

puts:
	lodsb
	cmpb	$2, %al
	jnc	putcs
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
	jnc	puts
	ret

#ifdef CHECK_FILES
msgok:
	.asciz	" OK"
msgko:
	.ascii	" Broken"
	.word	1			// next sector offset
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
#ifdef CHECK_FILES
msgnext:
	.asciz	"Next!"
#else
	.ascii	"SliTaz"
#endif
//	.word	0
//vidmode:
//	.word	0
//rootdev:
//	.word	0
bootflag:
	.word	0xAA55
