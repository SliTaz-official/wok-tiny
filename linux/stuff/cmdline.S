start_of_setup	=	0xF00
cmd_line_ptr	=	0x228
default_cmdline	=	0x300
#define ABS(x)	(x)-0x230
#ifdef BUGGY
#define	EDIT_CMDLINE
#endif

	.code16
	.org	0
	//.org	0x230
tranpoline:
	call	start_of_setup2
base	= 3
	rep
	  stosb
	popw	%ds
	ret

start_of_setup2:
	popw	%di	// caller nextip = base
	pushw	%di
	pushw	%ds	// caller %ds
	pushw	%cs
	popw	%ds
	xorl	%eax, %eax
	leaw	ABS(default_cmdline)-base(%di), %si
	cmpb	%al, (%si)
	je	no_cmdline
	orl	ABS(cmd_line_ptr)-base(%di), %eax
	jne	not_default
	cld

#ifdef	EDIT_CMDLINE
# The cmdline can be entered and modifed at boot time.
# Only characters before the cursor are passed to the kernel.

	movw	%ax, %es
	movw	%si, %dx
	movb	$13, %al
puts:
#ifdef BUGGY
	call	putc
#endif
	lodsb
	orb	%al, %al
	jnz	puts
endputs:
cmdlp:
	movb	$0x20, %al		# clear end of line
cmdlpz:
	call	putc			#  with Space
	subb	$0x18, %al		#   and BackSpace
	jnc	cmdlpz
	decw	%si
cmdget:
clock	= 0x46C
	movw	$clock, %bx
#define DELAY 5
	movb	$257-(DELAY*182)/10, %es:(%bx)
waitkbd:
	movw	$0x10D, %ax		# test keyboard, timeout => CR
	cmpb	%es:(%bx),%ah
	je	waitdone
	int	$0x16
	jz	waitkbd
	cbw
	int	$0x16			# eat char
	movw	%bx, %es		# disable timeout
waitdone:
	cmpb	$8, %al			# BackSpace ?
	je	cmdbs
	movb	%al, (%si)		# store char
	lodsw				# %si += 2
cmdbs:
	cmpw	%dx, %si
	je	cmdget
	call	putc
	cmpb	$10, %al		# Enter/linefeed ?
	jne	cmdlp
	movb	%bh,-2(%si)		# set end of string and remove CR
endcmdline:
	movw	%dx, %si
#endif

	xorw	%cx, %cx
len:
	lodsb
	orb	%al, %al
	loopne	len
	addw	%cx, %si
	cbw
	cdq
	andb	$0xFE, %cl
	popw	%bp		// caller %ds
	addw	%cx, %sp
	pushw	%di		// caller nextip
	pushw	%bp		// caller %ds
	pushw	%ss
	popw	%es
	movw	%sp, %ax
	movw	%es, %dx
	shll	$4, %edx
	addl	%eax, %edx
	movl	%edx, ABS(cmd_line_ptr)-base(%di)
	pushw	%di
	xchgw	%ax, %di
	negw	%cx
	rep
	  movsb
	popw	%di
not_default:
no_cmdline:
	pushw	%cs
	popw	%es
	movw	$ABS(start_of_setup)-base, %cx
	leaw	ABS(start_of_setup)-base(%di), %ax
	pushw	%ax
	xorw	%ax, %ax
	jmp	*%di

#ifdef	EDIT_CMDLINE
putlf:
	xorb	$10^13, %al
putc:
	movb	$0xe, %ah
	movw	$7, %bx
 	int	$0x10
	cmpb	$13, %al
	je	putlf
	ret
#endif

