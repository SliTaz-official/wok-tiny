	.text
	.code16
	.arch	i8086
	.org	0
	.globl	_start
_start:
	call	start2
start2:
	popw	%bx
	cmpb	$0x1, %bh
	je	dotcom
	xorw	%ax, %ax		# %ax = 0
	movw	%ax, %ds
	leaw	int21-start2(%bx), %ax
	movw	%ax,0x21*4
	movw	%cs,0x21*4+2
	movw	$0x7C0-0x10, %ax
	movw	%ax, %ds
dotcom:
	movw	%ds, %ax
	addw	$6, %ax			# addw $code/16, %ax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %ss
	movw	$0xFFFE, %sp
	pushw	%ds
	movw	$0x100, %ax
	pushw	%ax
	cbw
	xorw	%bx, %bx
	retf

int21:
	cmpb	$7, %ah
	jne	not_input
	movb	$0, %ah
	int	$0x16
do_iret:
	iret
not_input:
	cmpb	$9, %ah
	jne	abort
	movw	%dx, %si
puts:
	lodsb
	cmpb	$'$', %al
	je	do_iret
	movb	$0xe, %ah
	movw	$0xf, %bx
	int	$0x10
	jmp	puts
abort:
	ljmp	$0xffff,$0
	
	.org	0x60
code:
	.org	510	
	
	.word	0xaa55
