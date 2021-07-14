	.text
	.code16
	.arch	i8086
	.org	0
	.globl	_start
_start:
	call	start2
	
BPB	=	0x3E
#define TINY_MENU	Tiny SliTaz floppy boot menu
#ifdef	TINY_MENU
	.org	BPB-12
	xchgw	%ax, %di		# 79 58 41 E8
	popw	%ax
	incw	%cx
	call	called
called:
	addw	$0x20, %cs:bootseg+0x201	# code at 07C0:0200
	.org	BPB, 0x90
#endif
	
	.org	BPB
start2:
	popw	%ax
com_offset	=	0x100
	cmpw	$com_offset+3, %ax
	je	dotcom
	cwd
int21hook:
	movb	$int21-_start, %al
	movw	%dx, %ds
	movw	%ax, 0x21*4
	movw	%cs, 0x21*4+2
bootseg:
	movw	$0x7C0-com_offset/16, %ax
	.byte	0x3d			# cmp $0xc88c, %ax
dotcom:
	movw	%cs, %ax
paragraphs	=	9
	addw	$paragraphs, %ax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %ss
	movw	$0xFFFE, %sp
	pushw	%ax
	movw	$com_offset, %ax
	pushw	%ax
	cbw				# %ax = 0
	retf

int21:
	subb	$7, %ah
	jne	not_input
	int	$0x16			# %ah = 0
do_iret:
	iret
not_input:
	cmpb	$9-7, %ah
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

	.org	paragraphs*16	
code:
	.org	510	
	
	.word	0xaa55
