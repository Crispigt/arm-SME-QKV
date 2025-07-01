	.arch armv9.2-a+crc+sme2
	.file	"naive_mm_realdata.c"
	.text
	.align	2
	.p2align 5,,15
	.global	softmax_naive
	.type	softmax_naive, %function
softmax_naive:
.LFB22:
	.cfi_startproc
	cmp	w1, 0
	ble	.L18
	stp	x29, x30, [sp, -128]!
	.cfi_def_cfa_offset 128
	.cfi_offset 29, -128
	.cfi_offset 30, -120
	mov	x29, sp
	stp	x21, x22, [sp, 32]
	.cfi_offset 21, -96
	.cfi_offset 22, -88
	sub	w21, w2, #2
	mov	x22, x0
	add	x0, x0, 8
	stp	x23, x24, [sp, 48]
	.cfi_offset 23, -80
	.cfi_offset 24, -72
	sbfiz	x23, x2, 2, 32
	mov	w24, w1
	add	x21, x0, w21, uxtw 2
	mov	w1, 58350
	mov	w0, 58350
	stp	x19, x20, [sp, 16]
	.cfi_offset 19, -112
	.cfi_offset 20, -104
	add	x20, x22, x23
	movk	w1, 0x6c, lsl 16
	stp	x25, x26, [sp, 64]
	.cfi_offset 25, -64
	.cfi_offset 26, -56
	mov	w25, w2
	movk	w0, 0x806c, lsl 16
	mov	w26, 0
	stp	d11, d12, [sp, 80]
	.cfi_offset 75, -48
	.cfi_offset 76, -40
	fmov	s11, w0
	fmov	s12, 1.0e+0
	stp	d13, d14, [sp, 96]
	.cfi_offset 77, -32
	.cfi_offset 78, -24
	fmov	s13, w1
	str	d15, [sp, 112]
	.cfi_offset 79, -16
	.p2align 5,,15
.L10:
	ldr	s15, [x22]
	cmp	w25, 1
	ble	.L3
	add	x0, x22, 4
	.p2align 5,,15
.L4:
	ldr	s31, [x0], 4
	fcmpe	s31, s15
	fcsel	s15, s31, s15, gt
	cmp	x0, x21
	bne	.L4
.L3:
	cmp	w25, 0
	ble	.L1
	movi	v14.2s, #0
	mov	x19, x22
	.p2align 5,,15
.L5:
	ldr	s0, [x19], 4
	fsub	s0, s0, s15
	bl	expf
	fadd	s14, s14, s0
	cmp	x19, x20
	bne	.L5
	fcmpe	s14, s13
	bgt	.L6
	fcmpe	s14, s11
	bmi	.L6
	movi	v14.2s, #0
	.p2align 5,,15
.L7:
	mov	x19, x22
	.p2align 5,,15
.L9:
	ldr	s0, [x19]
	fsub	s0, s0, s15
	bl	expf
	fmul	s0, s0, s14
	str	s0, [x19], 4
	cmp	x20, x19
	bne	.L9
	add	w26, w26, 1
	add	x22, x22, x23
	add	x20, x20, x23
	add	x21, x21, x23
	cmp	w24, w26
	bne	.L10
.L1:
	ldr	d15, [sp, 112]
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x23, x24, [sp, 48]
	ldp	x25, x26, [sp, 64]
	ldp	d11, d12, [sp, 80]
	ldp	d13, d14, [sp, 96]
	ldp	x29, x30, [sp], 128
	.cfi_remember_state
	.cfi_restore 30
	.cfi_restore 29
	.cfi_restore 25
	.cfi_restore 26
	.cfi_restore 23
	.cfi_restore 24
	.cfi_restore 21
	.cfi_restore 22
	.cfi_restore 19
	.cfi_restore 20
	.cfi_restore 79
	.cfi_restore 77
	.cfi_restore 78
	.cfi_restore 75
	.cfi_restore 76
	.cfi_def_cfa_offset 0
	ret
	.p2align 2,,3
.L6:
	.cfi_restore_state
	fdiv	s14, s12, s14
	b	.L7
.L18:
	.cfi_def_cfa_offset 0
	.cfi_restore 19
	.cfi_restore 20
	.cfi_restore 21
	.cfi_restore 22
	.cfi_restore 23
	.cfi_restore 24
	.cfi_restore 25
	.cfi_restore 26
	.cfi_restore 29
	.cfi_restore 30
	.cfi_restore 75
	.cfi_restore 76
	.cfi_restore 77
	.cfi_restore 78
	.cfi_restore 79
	ret
	.cfi_endproc
.LFE22:
	.size	softmax_naive, .-softmax_naive
	.align	2
	.p2align 5,,15
	.global	matrix_multiply_naive
	.type	matrix_multiply_naive, %function
matrix_multiply_naive:
.LFB23:
	.cfi_startproc
	mov	w13, w3
	mov	x12, x0
	mov	x14, x1
	mov	w10, w4
	cmp	w3, 0
	ble	.L22
	cmp	w5, 0
	ble	.L22
	sxtw	x7, w5
	mov	x3, x2
	ubfiz	x5, x5, 2, 32
	sxtw	x15, w4
	mov	w9, 0
	mov	w11, 0
	.p2align 5,,15
.L25:
	add	x4, x15, w9, sxtw
	mov	x6, x14
	add	x8, x12, w9, sxtw 2
	mov	x2, 0
	add	x4, x12, x4, lsl 2
.L27:
	str	wzr, [x3, x2, lsl 2]
	cmp	w10, 0
	bgt	.L26
	add	x2, x2, 1
	add	x6, x6, 4
	cmp	x7, x2
	bne	.L27
	.p2align 5,,15
.L28:
	add	w11, w11, 1
	add	x3, x3, x5
	add	w9, w9, w10
	cmp	w13, w11
	bne	.L25
.L22:
	ret
	.p2align 2,,3
.L34:
	add	x2, x2, 1
	add	x6, x6, 4
	cmp	x7, x2
	beq	.L28
	str	wzr, [x3, x2, lsl 2]
.L26:
	movi	v31.2s, #0
	mov	x1, x6
	mov	x0, x8
	.p2align 5,,15
.L29:
	ldr	s29, [x1]
	add	x1, x1, x5
	ldr	s30, [x0], 4
	fmadd	s31, s30, s29, s31
	str	s31, [x3, x2, lsl 2]
	cmp	x4, x0
	bne	.L29
	b	.L34
	.cfi_endproc
.LFE23:
	.size	matrix_multiply_naive, .-matrix_multiply_naive
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC0:
	.string	"r"
	.align	3
.LC1:
	.string	"Error opening file"
	.align	3
.LC2:
	.string	"Failed to open: %s\n"
	.align	3
.LC3:
	.string	"%d %d"
	.align	3
.LC4:
	.string	"Error reading dimensions from %s\n"
	.align	3
.LC5:
	.string	"Invalid dimensions (%d x %d) read from %s\n"
	.align	3
.LC6:
	.string	"Error allocating memory for matrix"
	.align	3
.LC7:
	.string	"%f"
	.align	3
.LC8:
	.string	"Error reading matrix data element %d from %s\n"
	.text
	.align	2
	.p2align 5,,15
	.global	load_matrix_data
	.type	load_matrix_data, %function
load_matrix_data:
.LFB24:
	.cfi_startproc
	stp	x29, x30, [sp, -80]!
	.cfi_def_cfa_offset 80
	.cfi_offset 29, -80
	.cfi_offset 30, -72
	mov	x29, sp
	stp	x19, x20, [sp, 16]
	.cfi_offset 19, -64
	.cfi_offset 20, -56
	mov	x20, x1
	mov	x19, x2
	adrp	x1, .LC0
	add	x1, x1, :lo12:.LC0
	stp	x23, x24, [sp, 48]
	str	x25, [sp, 64]
	.cfi_offset 23, -32
	.cfi_offset 24, -24
	.cfi_offset 25, -16
	mov	x25, x0
	bl	fopen
	cbz	x0, .L46
	adrp	x1, .LC3
	mov	x3, x19
	add	x1, x1, :lo12:.LC3
	mov	x2, x20
	stp	x21, x22, [sp, 32]
	.cfi_offset 22, -40
	.cfi_offset 21, -48
	mov	x21, x0
	bl	__isoc99_fscanf
	cmp	w0, 2
	bne	.L47
	ldr	w3, [x19]
	ldr	w2, [x20]
	mul	w23, w2, w3
	cmp	w23, 0
	ble	.L48
	ubfiz	x0, x23, 2, 32
	bl	malloc
	mov	x24, x0
	cbz	x0, .L49
	adrp	x22, .LC7
	mov	x19, x0
	add	x22, x22, :lo12:.LC7
	mov	w20, 0
	.p2align 5,,15
.L43:
	mov	x2, x19
	mov	x1, x22
	mov	x0, x21
	add	x19, x19, 4
	bl	__isoc99_fscanf
	cmp	w0, 1
	bne	.L50
	add	w20, w20, 1
	cmp	w23, w20
	bne	.L43
	mov	x0, x21
	bl	fclose
	ldr	x25, [sp, 64]
	mov	x0, x24
	ldp	x21, x22, [sp, 32]
	.cfi_remember_state
	.cfi_restore 22
	.cfi_restore 21
	ldp	x19, x20, [sp, 16]
	ldp	x23, x24, [sp, 48]
	ldp	x29, x30, [sp], 80
	.cfi_restore 30
	.cfi_restore 29
	.cfi_restore 25
	.cfi_restore 23
	.cfi_restore 24
	.cfi_restore 19
	.cfi_restore 20
	.cfi_def_cfa_offset 0
	ret
	.p2align 2,,3
.L50:
	.cfi_restore_state
	adrp	x0, stderr
	mov	x3, x25
	mov	w2, w20
	adrp	x1, .LC8
	ldr	x0, [x0, #:lo12:stderr]
	add	x1, x1, :lo12:.LC8
	bl	fprintf
	mov	x0, x24
	bl	free
	mov	x0, x21
	bl	fclose
	ldp	x21, x22, [sp, 32]
	.cfi_restore 22
	.cfi_restore 21
	mov	x24, 0
.L51:
	ldr	x25, [sp, 64]
	mov	x0, x24
	ldp	x19, x20, [sp, 16]
	ldp	x23, x24, [sp, 48]
	ldp	x29, x30, [sp], 80
	.cfi_restore 30
	.cfi_restore 29
	.cfi_restore 25
	.cfi_restore 23
	.cfi_restore 24
	.cfi_restore 19
	.cfi_restore 20
	.cfi_def_cfa_offset 0
	ret
	.p2align 2,,3
.L47:
	.cfi_def_cfa_offset 80
	.cfi_offset 19, -64
	.cfi_offset 20, -56
	.cfi_offset 21, -48
	.cfi_offset 22, -40
	.cfi_offset 23, -32
	.cfi_offset 24, -24
	.cfi_offset 25, -16
	.cfi_offset 29, -80
	.cfi_offset 30, -72
	adrp	x0, stderr
	mov	x2, x25
	adrp	x1, .LC4
	add	x1, x1, :lo12:.LC4
	ldr	x0, [x0, #:lo12:stderr]
	mov	x24, 0
	bl	fprintf
	mov	x0, x21
	bl	fclose
	ldp	x21, x22, [sp, 32]
	.cfi_remember_state
	.cfi_restore 22
	.cfi_restore 21
	b	.L51
	.p2align 2,,3
.L48:
	.cfi_restore_state
	adrp	x0, stderr
	mov	x4, x25
	adrp	x1, .LC5
	add	x1, x1, :lo12:.LC5
	ldr	x0, [x0, #:lo12:stderr]
	mov	x24, 0
	bl	fprintf
	mov	x0, x21
	bl	fclose
	ldp	x21, x22, [sp, 32]
	.cfi_restore 22
	.cfi_restore 21
	b	.L51
	.p2align 2,,3
.L46:
	adrp	x0, .LC1
	add	x0, x0, :lo12:.LC1
	bl	perror
	mov	x24, 0
	adrp	x0, stderr
	mov	x2, x25
	adrp	x1, .LC2
	add	x1, x1, :lo12:.LC2
	ldr	x0, [x0, #:lo12:stderr]
	bl	fprintf
	b	.L51
.L49:
	.cfi_offset 21, -48
	.cfi_offset 22, -40
	adrp	x0, .LC6
	add	x0, x0, :lo12:.LC6
	bl	perror
	mov	x24, 0
	mov	x0, x21
	bl	fclose
	ldp	x21, x22, [sp, 32]
	.cfi_restore 22
	.cfi_restore 21
	b	.L51
	.cfi_endproc
.LFE24:
	.size	load_matrix_data, .-load_matrix_data
	.section	.rodata.str1.8
	.align	3
.LC9:
	.string	"Invalid input to transpose function\n"
	.align	3
.LC10:
	.string	"Error allocating memory for transposed matrix"
	.text
	.align	2
	.p2align 5,,15
	.global	transpose
	.type	transpose, %function
transpose:
.LFB25:
	.cfi_startproc
	stp	x29, x30, [sp, -64]!
	.cfi_def_cfa_offset 64
	.cfi_offset 29, -64
	.cfi_offset 30, -56
	cmp	w1, 0
	ccmp	w2, 0, 4, gt
	mov	x29, sp
	ccmp	x0, 0, 4, gt
	beq	.L77
	stp	x19, x20, [sp, 16]
	.cfi_offset 20, -40
	.cfi_offset 19, -48
	mov	w20, w2
	sxtw	x19, w1
	stp	x23, x24, [sp, 48]
	.cfi_offset 24, -8
	.cfi_offset 23, -16
	ubfiz	x23, x20, 2, 32
	sxtw	x24, w2
	stp	x21, x22, [sp, 32]
	.cfi_offset 22, -24
	.cfi_offset 21, -32
	mov	x22, x0
	mul	x0, x19, x23
	mov	w21, w1
	bl	malloc
	cbz	x0, .L55
	mov	w6, 12
	mov	x11, x22
	mov	x13, x0
	ubfiz	x8, x21, 4, 32
	umull	x6, w21, w6
	ubfiz	x17, x21, 2, 32
	ubfiz	x7, x21, 3, 32
	and	w1, w20, -4
	lsr	w16, w20, 2
	mov	x12, 0
	mov	x10, 0
	.p2align 5,,15
.L56:
	mov	w15, w10
	mov	w14, w12
	cmp	w20, 3
	ble	.L65
	mov	w9, w1
.L60:
	add	x5, x11, w16, uxtw 4
	mov	x4, x13
	mov	x3, x11
	.p2align 5,,15
.L63:
	ldp	s30, s31, [x3, 8]
	ldp	s28, s29, [x3], 16
	str	s28, [x4]
	str	s29, [x4, x19, lsl 2]
	str	s30, [x4, x7]
	str	s31, [x4, x6]
	add	x4, x4, x8
	cmp	x5, x3
	bne	.L63
	mov	w3, w1
	cmp	w20, w1
	beq	.L78
.L58:
	sub	w2, w20, w9
	cmp	w2, 1
	beq	.L61
	add	x4, x12, w9, uxtw
	umaddl	x9, w19, w9, x10
	add	x5, x22, x4, lsl 2
	ldr	s30, [x22, x4, lsl 2]
	add	x4, x0, x9, lsl 2
	ldr	s31, [x5, 4]
	str	s30, [x0, x9, lsl 2]
	str	s31, [x4, x17]
	tbz	x2, 0, .L62
	and	w2, w2, -2
	add	w3, w3, w2
.L61:
	add	w14, w3, w14
	madd	w3, w21, w3, w15
	ldr	s31, [x22, x14, lsl 2]
	str	s31, [x0, x3, lsl 2]
.L62:
	add	x10, x10, 1
	add	x11, x11, x23
	add	x13, x13, 4
	add	x12, x12, x24
	cmp	w21, w10
	bgt	.L56
.L76:
	ldp	x19, x20, [sp, 16]
	.cfi_remember_state
	.cfi_restore 20
	.cfi_restore 19
	ldp	x21, x22, [sp, 32]
	.cfi_restore 22
	.cfi_restore 21
	ldp	x23, x24, [sp, 48]
	.cfi_restore 24
	.cfi_restore 23
	ldp	x29, x30, [sp], 64
	.cfi_restore 30
	.cfi_restore 29
	.cfi_def_cfa_offset 0
	ret
	.p2align 2,,3
.L78:
	.cfi_restore_state
	add	x10, x10, 1
	add	x11, x11, x23
	add	x13, x13, 4
	add	x12, x12, x24
	cmp	w21, w10
	ble	.L76
	mov	w15, w10
	mov	w14, w12
	b	.L60
	.p2align 2,,3
.L65:
	mov	w9, 0
	mov	w3, 0
	b	.L58
.L77:
	.cfi_restore 19
	.cfi_restore 20
	.cfi_restore 21
	.cfi_restore 22
	.cfi_restore 23
	.cfi_restore 24
	adrp	x1, stderr
	adrp	x0, .LC9
	mov	x2, 36
	add	x0, x0, :lo12:.LC9
	ldr	x3, [x1, #:lo12:stderr]
	mov	x1, 1
	bl	fwrite
	mov	x0, 0
.L79:
	ldp	x29, x30, [sp], 64
	.cfi_restore 30
	.cfi_restore 29
	.cfi_def_cfa_offset 0
	ret
.L55:
	.cfi_def_cfa_offset 64
	.cfi_offset 19, -48
	.cfi_offset 20, -40
	.cfi_offset 21, -32
	.cfi_offset 22, -24
	.cfi_offset 23, -16
	.cfi_offset 24, -8
	.cfi_offset 29, -64
	.cfi_offset 30, -56
	adrp	x0, .LC10
	add	x0, x0, :lo12:.LC10
	bl	perror
	mov	x0, 0
	ldp	x19, x20, [sp, 16]
	.cfi_restore 20
	.cfi_restore 19
	ldp	x21, x22, [sp, 32]
	.cfi_restore 22
	.cfi_restore 21
	ldp	x23, x24, [sp, 48]
	.cfi_restore 24
	.cfi_restore 23
	b	.L79
	.cfi_endproc
.LFE25:
	.size	transpose, .-transpose
	.section	.rodata.str1.8
	.align	3
.LC11:
	.string	"Matrix %s (%dx%d):\n"
	.align	3
.LC12:
	.string	" (NULL)"
	.align	3
.LC13:
	.string	"%f "
	.align	3
.LC14:
	.string	"----"
	.text
	.align	2
	.p2align 5,,15
	.global	print_matrix
	.type	print_matrix, %function
print_matrix:
.LFB26:
	.cfi_startproc
	stp	x29, x30, [sp, -96]!
	.cfi_def_cfa_offset 96
	.cfi_offset 29, -96
	.cfi_offset 30, -88
	mov	x29, sp
	stp	x23, x24, [sp, 48]
	.cfi_offset 23, -48
	.cfi_offset 24, -40
	mov	x24, x1
	mov	x1, x0
	adrp	x0, .LC11
	add	x0, x0, :lo12:.LC11
	stp	x25, x26, [sp, 64]
	.cfi_offset 25, -32
	.cfi_offset 26, -24
	mov	w26, w2
	mov	w25, w3
	bl	printf
	cbz	x24, .L81
	cmp	w26, 0
	ble	.L82
	mov	w23, 0
	stp	x21, x22, [sp, 32]
	.cfi_offset 22, -56
	.cfi_offset 21, -64
	mov	w22, 0
.L83:
	mov	w0, 10
	cmp	w25, 0
	bgt	.L93
	add	w23, w23, 1
	bl	putchar
	add	w22, w22, w25
	cmp	w26, w23
	bne	.L83
	ldp	x21, x22, [sp, 32]
	.cfi_restore 22
	.cfi_restore 21
.L82:
	adrp	x0, .LC14
	ldp	x23, x24, [sp, 48]
	add	x0, x0, :lo12:.LC14
	ldp	x25, x26, [sp, 64]
	ldp	x29, x30, [sp], 96
	.cfi_restore 30
	.cfi_restore 29
	.cfi_restore 25
	.cfi_restore 26
	.cfi_restore 23
	.cfi_restore 24
	.cfi_def_cfa_offset 0
	b	puts
	.p2align 2,,3
.L93:
	.cfi_def_cfa_offset 96
	.cfi_offset 21, -64
	.cfi_offset 22, -56
	.cfi_offset 23, -48
	.cfi_offset 24, -40
	.cfi_offset 25, -32
	.cfi_offset 26, -24
	.cfi_offset 29, -96
	.cfi_offset 30, -88
	adrp	x21, .LC13
	add	x21, x21, :lo12:.LC13
	str	x27, [sp, 80]
	.cfi_offset 27, -16
	sxtw	x27, w25
	stp	x19, x20, [sp, 16]
	.cfi_offset 20, -72
	.cfi_offset 19, -80
	.p2align 5,,15
.L85:
	add	x20, x27, w22, sxtw
	add	x19, x24, w22, uxtw 2
	add	x20, x24, w20, uxtw 2
	.p2align 5,,15
.L84:
	ldr	s0, [x19], 4
	mov	x0, x21
	fcvt	d0, s0
	bl	printf
	cmp	x20, x19
	bne	.L84
	mov	w0, 10
	add	w23, w23, 1
	bl	putchar
	add	w22, w22, w25
	cmp	w26, w23
	bne	.L85
	ldr	x27, [sp, 80]
	.cfi_restore 27
	adrp	x0, .LC14
	ldp	x19, x20, [sp, 16]
	.cfi_restore 20
	.cfi_restore 19
	add	x0, x0, :lo12:.LC14
	ldp	x21, x22, [sp, 32]
	.cfi_restore 22
	.cfi_restore 21
	ldp	x23, x24, [sp, 48]
	ldp	x25, x26, [sp, 64]
	ldp	x29, x30, [sp], 96
	.cfi_restore 30
	.cfi_restore 29
	.cfi_restore 25
	.cfi_restore 26
	.cfi_restore 23
	.cfi_restore 24
	.cfi_def_cfa_offset 0
	b	puts
.L81:
	.cfi_def_cfa_offset 96
	.cfi_offset 23, -48
	.cfi_offset 24, -40
	.cfi_offset 25, -32
	.cfi_offset 26, -24
	.cfi_offset 29, -96
	.cfi_offset 30, -88
	ldp	x23, x24, [sp, 48]
	adrp	x0, .LC12
	ldp	x25, x26, [sp, 64]
	add	x0, x0, :lo12:.LC12
	ldp	x29, x30, [sp], 96
	.cfi_restore 30
	.cfi_restore 29
	.cfi_restore 25
	.cfi_restore 26
	.cfi_restore 23
	.cfi_restore 24
	.cfi_def_cfa_offset 0
	b	puts
	.cfi_endproc
.LFE26:
	.size	print_matrix, .-print_matrix
	.section	.rodata.str1.8
	.align	3
.LC15:
	.string	"Mismatch at row %d, col %d (index %d): A=%f, B=%f, Diff=%f\n"
	.text
	.align	2
	.p2align 5,,15
	.global	compare_matrices
	.type	compare_matrices, %function
compare_matrices:
.LFB27:
	.cfi_startproc
	cmp	x0, 0
	ccmp	x1, 0, 4, ne
	beq	.L105
	mul	w2, w2, w3
	cmp	w2, 0
	ble	.L100
	sxtw	x2, w2
	mov	x5, 0
	.p2align 5,,15
.L99:
	ldr	s31, [x0, x5, lsl 2]
	ldr	s1, [x1, x5, lsl 2]
	fabd	s2, s31, s1
	fcmpe	s2, s0
	bgt	.L101
	add	x5, x5, 1
	cmp	x2, x5
	bne	.L99
.L100:
	mov	w0, 1
	ret
	.p2align 2,,3
.L105:
	mov	w0, 0
	ret
	.p2align 2,,3
.L101:
	sdiv	w2, w5, w3
	stp	x29, x30, [sp, -16]!
	.cfi_def_cfa_offset 16
	.cfi_offset 29, -16
	.cfi_offset 30, -8
	adrp	x0, stderr
	mov	x29, sp
	fcvt	d2, s2
	fcvt	d1, s1
	fcvt	d0, s31
	msub	w3, w2, w3, w5
	mov	w4, w5
	ldr	x0, [x0, #:lo12:stderr]
	adrp	x1, .LC15
	add	x1, x1, :lo12:.LC15
	bl	fprintf
	mov	w0, 0
	ldp	x29, x30, [sp], 16
	.cfi_restore 30
	.cfi_restore 29
	.cfi_def_cfa_offset 0
	ret
	.cfi_endproc
.LFE27:
	.size	compare_matrices, .-compare_matrices
	.section	.rodata.str1.8
	.align	3
.LC16:
	.string	"%s/head_%02d/q_matrix.txt"
	.align	3
.LC17:
	.string	"%s/head_%02d/k_matrix.txt"
	.align	3
.LC18:
	.string	"%s/head_%02d/v_matrix.txt"
	.align	3
.LC19:
	.string	"%s/head_%02d/expected_context.txt"
	.align	3
.LC20:
	.string	"Head %02d: Failed to transpose K"
	.align	3
.LC21:
	.string	"Head %02d: Failed to allocate QK_T_scaled"
	.align	3
.LC22:
	.string	"Head %02d: Failed to allocate Output"
	.align	3
.LC23:
	.string	"Head %02d: >>> TEST FAILED <<< :(\n"
	.align	3
.LC24:
	.string	"Head %02d: Calculated output does not match expected output within tolerance %f.\n"
	.text
	.align	2
	.p2align 5,,15
	.global	run_attention_test_for_head
	.type	run_attention_test_for_head, %function
run_attention_test_for_head:
.LFB28:
	.cfi_startproc
	sub	sp, sp, #2192
	.cfi_def_cfa_offset 2192
	mov	w4, w1
	mov	x3, x0
	adrp	x2, .LC16
	add	x2, x2, :lo12:.LC16
	stp	x29, x30, [sp]
	.cfi_offset 29, -2192
	.cfi_offset 30, -2184
	mov	x29, sp
	stp	x19, x20, [sp, 16]
	.cfi_offset 19, -2176
	.cfi_offset 20, -2168
	mov	x19, x0
	add	x0, sp, 144
	stp	x21, x22, [sp, 32]
	.cfi_offset 21, -2160
	.cfi_offset 22, -2152
	mov	w21, w1
	mov	x1, 512
	stp	x25, x26, [sp, 64]
	stp	x27, x28, [sp, 80]
	stp	wzr, wzr, [sp, 116]
	stp	wzr, wzr, [sp, 124]
	stp	wzr, wzr, [sp, 132]
	str	wzr, [sp, 140]
	.cfi_offset 25, -2128
	.cfi_offset 26, -2120
	.cfi_offset 27, -2112
	.cfi_offset 28, -2104
	bl	snprintf
	mov	x3, x19
	mov	w4, w21
	mov	x1, 512
	add	x0, sp, 656
	adrp	x2, .LC17
	add	x2, x2, :lo12:.LC17
	bl	snprintf
	mov	x3, x19
	mov	w4, w21
	mov	x1, 512
	add	x0, sp, 1168
	adrp	x2, .LC18
	add	x2, x2, :lo12:.LC18
	bl	snprintf
	mov	x3, x19
	mov	w4, w21
	mov	x1, 512
	add	x0, sp, 1680
	adrp	x2, .LC19
	add	x2, x2, :lo12:.LC19
	bl	snprintf
	add	x2, sp, 120
	add	x1, sp, 116
	add	x0, sp, 144
	bl	load_matrix_data
	add	x2, sp, 120
	add	x1, sp, 128
	mov	x27, x0
	add	x0, sp, 656
	bl	load_matrix_data
	mov	x19, x0
	add	x2, sp, 124
	add	x1, sp, 132
	str	x0, [sp, 96]
	add	x0, sp, 1168
	bl	load_matrix_data
	mov	x25, x0
	add	x2, sp, 140
	add	x1, sp, 136
	add	x0, sp, 1680
	bl	load_matrix_data
	ldp	w1, w2, [sp, 116]
	mov	x20, x0
	mov	x0, x19
	bl	transpose
	mov	x19, x0
	cbz	x0, .L156
	stp	x23, x24, [sp, 48]
	.cfi_offset 24, -2136
	.cfi_offset 23, -2144
	ldr	w24, [sp, 116]
	mul	w13, w24, w24
	str	w13, [sp, 104]
	ubfiz	x0, x13, 2, 32
	bl	malloc
	mov	x26, x0
	ldr	w13, [sp, 104]
	cbz	x0, .L157
	ldr	w22, [sp, 124]
	mul	w0, w24, w22
	stp	w0, w13, [sp, 104]
	sxtw	x23, w0
	sbfiz	x0, x0, 2, 32
	bl	malloc
	mov	x28, x0
	ldr	w13, [sp, 108]
	cbz	x0, .L158
	ldr	w5, [sp, 120]
	cmp	w24, 0
	ble	.L114
	sxtw	x2, w24
	cntb	x0
	whilelo	p15.s, wzr, w5
	ubfiz	x14, x24, 2, 32
	mov	x12, x26
	add	x9, x19, x14
	mov	w11, 0
	mul	x2, x2, x0
	mov	w10, 0
	asr	x1, x14, 2
	index	z31.s, #0, w1
	.p2align 5,,15
.L115:
	add	x1, x27, w11, sxtw 2
	mov	x7, x19
	mov	x8, x12
.L120:
	str	wzr, [x8]
	cmp	w5, 0
	bgt	.L119
	add	x7, x7, 4
	add	x8, x8, 4
	cmp	x7, x9
	bne	.L120
	.p2align 5,,15
.L118:
	add	w10, w10, 1
	add	x12, x12, x14
	add	w11, w11, w5
	cmp	w24, w10
	bne	.L115
	scvtf	s0, w5
	fcmp	s0, #0.0
	bpl	.L140
	str	w13, [sp, 108]
	bl	sqrtf
	fmov	s30, 1.0e+0
	ldr	w13, [sp, 108]
	fdiv	s30, s30, s0
	b	.L124
	.p2align 2,,3
.L159:
	add	x7, x7, 4
	str	s30, [x8], 4
	cmp	x7, x9
	beq	.L118
	str	wzr, [x8]
.L119:
	movi	v30.2s, #0
	mov	x4, x7
	mov	p7.b, p15.b
	mov	x0, 0
	.p2align 5,,15
.L117:
	ld1w	z29.s, p7/z, [x1, x0, lsl 2]
	ld1w	z28.s, p7/z, [x4, z31.s, sxtw 2]
	incw	x0
	fmul	z29.s, p7/m, z29.s, z28.s
	add	x4, x4, x2
	fadda	s30, p7, s30, z29.s
	whilelo	p7.s, w0, w5
	b.any	.L117
	b	.L159
.L140:
	fsqrt	s0, s0
	fmov	s30, 1.0e+0
	fdiv	s30, s30, s0
.L124:
	mov	x0, 0
	mov	z30.s, s30
	whilelo	p7.s, wzr, w13
	.p2align 5,,15
.L131:
	ld1w	z31.s, p7/z, [x26, x0, lsl 2]
	fmul	z31.s, p7/m, z31.s, z30.s
	st1w	z31.s, p7, [x26, x0, lsl 2]
	incw	x0
	whilelo	p7.s, w0, w13
	b.any	.L131
.L132:
	mov	w2, w24
	mov	w1, w24
	mov	x0, x26
	bl	softmax_naive
	cmp	w24, 0
	ble	.L129
	cmp	w22, 0
	ble	.L129
	sxtw	x2, w22
	cntb	x0
	index	z27.s, #0, w22
	ubfiz	x8, x22, 2, 32
	mov	x7, x28
	whilelo	p15.s, wzr, w24
	ubfiz	x10, x24, 2, 32
	mov	x1, x26
	mul	x2, x2, x0
	mov	w9, 0
	.p2align 5,,15
.L130:
	mov	x5, 0
	.p2align 5,,15
.L134:
	movi	v26.2s, #0
	add	x4, x25, x5
	mov	p7.b, p15.b
	mov	x0, 0
	.p2align 5,,15
.L133:
	ld1w	z25.s, p7/z, [x1, x0, lsl 2]
	ld1w	z24.s, p7/z, [x4, z27.s, sxtw 2]
	incw	x0
	fmul	z25.s, p7/m, z25.s, z24.s
	add	x4, x4, x2
	fadda	s26, p7, s26, z25.s
	whilelo	p7.s, w0, w24
	b.any	.L133
	str	s26, [x7, x5]
	add	x5, x5, 4
	cmp	x8, x5
	bne	.L134
	add	w9, w9, 1
	add	x7, x7, x8
	add	x1, x1, x10
	cmp	w24, w9
	bne	.L130
.L129:
	cbz	x20, .L160
	ldr	w0, [sp, 104]
	cmp	w0, 0
	ble	.L139
	mov	w0, 46871
	mov	x3, 0
	movk	w0, 0x38d1, lsl 16
	fmov	s31, w0
.L138:
	ldr	s0, [x28, x3, lsl 2]
	ldr	s1, [x20, x3, lsl 2]
	fabd	s2, s0, s1
	fcmpe	s2, s31
	bgt	.L142
	add	x3, x3, 1
	cmp	x23, x3
	bne	.L138
.L139:
	ldp	x23, x24, [sp, 48]
	.cfi_restore 24
	.cfi_restore 23
	mov	w21, 1
.L112:
	mov	x0, x27
	bl	free
	ldr	x0, [sp, 96]
	bl	free
	mov	x0, x25
	bl	free
	mov	x0, x20
	bl	free
	mov	x0, x19
	bl	free
	mov	x0, x26
	bl	free
	mov	x0, x28
	bl	free
	ldp	x29, x30, [sp]
	mov	w0, w21
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x25, x26, [sp, 64]
	ldp	x27, x28, [sp, 80]
	add	sp, sp, 2192
	.cfi_restore 27
	.cfi_restore 28
	.cfi_restore 25
	.cfi_restore 26
	.cfi_restore 21
	.cfi_restore 22
	.cfi_restore 19
	.cfi_restore 20
	.cfi_restore 29
	.cfi_restore 30
	.cfi_def_cfa_offset 0
	ret
.L160:
	.cfi_def_cfa_offset 2192
	.cfi_offset 19, -2176
	.cfi_offset 20, -2168
	.cfi_offset 21, -2160
	.cfi_offset 22, -2152
	.cfi_offset 23, -2144
	.cfi_offset 24, -2136
	.cfi_offset 25, -2128
	.cfi_offset 26, -2120
	.cfi_offset 27, -2112
	.cfi_offset 28, -2104
	.cfi_offset 29, -2192
	.cfi_offset 30, -2184
	adrp	x23, stderr
.L135:
	mov	w1, w21
	adrp	x0, .LC23
	add	x0, x0, :lo12:.LC23
	bl	printf
	adrp	x1, .LC25
	mov	w2, w21
	ldr	x0, [x23, #:lo12:stderr]
	mov	w21, 0
	ldr	d0, [x1, #:lo12:.LC25]
	adrp	x1, .LC24
	add	x1, x1, :lo12:.LC24
	bl	fprintf
	ldp	x23, x24, [sp, 48]
	.cfi_remember_state
	.cfi_restore 24
	.cfi_restore 23
	b	.L112
.L142:
	.cfi_restore_state
	sdiv	w2, w3, w22
	adrp	x23, stderr
	mov	w4, w3
	fcvt	d2, s2
	fcvt	d1, s1
	fcvt	d0, s0
	ldr	x0, [x23, #:lo12:stderr]
	msub	w3, w2, w22, w3
	adrp	x1, .LC15
	add	x1, x1, :lo12:.LC15
	bl	fprintf
	b	.L135
.L156:
	.cfi_restore 23
	.cfi_restore 24
	adrp	x0, .LC20
	add	x0, x0, :lo12:.LC20
	bl	perror
.L110:
	mov	w21, 0
	mov	x28, 0
	mov	x26, 0
	b	.L112
.L114:
	.cfi_offset 23, -2144
	.cfi_offset 24, -2136
	scvtf	s0, w5
	fcmp	s0, #0.0
	bpl	.L141
	str	w13, [sp, 108]
	bl	sqrtf
	ldr	w13, [sp, 108]
	cbz	w13, .L132
.L128:
	fmov	s30, 1.0e+0
	fdiv	s30, s30, s0
	b	.L124
	.p2align 2,,3
.L141:
	fsqrt	s0, s0
	cbz	w13, .L132
	b	.L128
.L158:
	adrp	x0, .LC22
	mov	w21, 0
	add	x0, x0, :lo12:.LC22
	bl	perror
	ldp	x23, x24, [sp, 48]
	.cfi_remember_state
	.cfi_restore 24
	.cfi_restore 23
	b	.L112
.L157:
	.cfi_restore_state
	adrp	x0, .LC21
	add	x0, x0, :lo12:.LC21
	bl	perror
	ldp	x23, x24, [sp, 48]
	.cfi_restore 24
	.cfi_restore 23
	b	.L110
	.cfi_endproc
.LFE28:
	.size	run_attention_test_for_head, .-run_attention_test_for_head
	.section	.rodata.str1.8
	.align	3
.LC26:
	.string	"tests/workload_different_sizes/real_qkv_core_test_data_layer0_32"
	.align	3
.LC27:
	.string	"Error: Number of heads must be positive.\n"
	.align	3
.LC28:
	.string	"Usage: %s [base_directory_path num_heads]\n"
	.align	3
.LC29:
	.string	"Example: %s real_qkv_core_test_data_layer0 12\n"
	.align	3
.LC30:
	.string	"Starting Attention Core Test"
	.align	3
.LC31:
	.string	"Base Directory: %s\n"
	.align	3
.LC32:
	.string	"\n--- Test Summary ---"
	.align	3
.LC33:
	.string	"------------------------"
	.align	3
.LC34:
	.string	">>> OVERALL TEST PASSED <<< :D"
	.align	3
.LC35:
	.string	"One or more head tests FAILED."
	.align	3
.LC36:
	.string	">>> OVERALL TEST FAILED <<< D:"
	.section	.text.startup,"ax",@progbits
	.align	2
	.p2align 5,,15
	.global	main
	.type	main, %function
main:
.LFB29:
	.cfi_startproc
	stp	x29, x30, [sp, -48]!
	.cfi_def_cfa_offset 48
	.cfi_offset 29, -48
	.cfi_offset 30, -40
	mov	x29, sp
	stp	x19, x20, [sp, 16]
	.cfi_offset 19, -32
	.cfi_offset 20, -24
	mov	x19, x1
	stp	x21, x22, [sp, 32]
	.cfi_offset 21, -16
	.cfi_offset 22, -8
	cmp	w0, 3
	beq	.L171
	cmp	w0, 1
	bne	.L172
	adrp	x21, .LC26
	add	x21, x21, :lo12:.LC26
	mov	w22, 12
.L163:
	mov	w19, 0
	mov	w20, 1
	adrp	x0, .LC30
	add	x0, x0, :lo12:.LC30
	bl	puts
	mov	x1, x21
	adrp	x0, .LC31
	add	x0, x0, :lo12:.LC31
	bl	printf
	.p2align 5,,15
.L166:
	mov	w1, w19
	mov	x0, x21
	bl	run_attention_test_for_head
	tst	w0, 255
	ccmp	w20, 0, 4, ne
	add	w19, w19, 1
	cset	w20, ne
	cmp	w22, w19
	bne	.L166
	adrp	x0, .LC32
	add	x0, x0, :lo12:.LC32
	bl	puts
	cbz	w20, .L167
	adrp	x19, .LC33
	add	x19, x19, :lo12:.LC33
	mov	x0, x19
	bl	puts
	adrp	x0, .LC34
	add	x0, x0, :lo12:.LC34
	bl	puts
	mov	x0, x19
	bl	puts
	mov	w0, 0
	b	.L161
.L167:
	adrp	x0, .LC35
	adrp	x19, .LC33
	add	x0, x0, :lo12:.LC35
	add	x19, x19, :lo12:.LC33
	bl	puts
	mov	x0, x19
	bl	puts
	adrp	x0, .LC36
	add	x0, x0, :lo12:.LC36
	bl	puts
	mov	x0, x19
	bl	puts
.L164:
	mov	w0, 1
.L161:
	ldp	x19, x20, [sp, 16]
	ldp	x21, x22, [sp, 32]
	ldp	x29, x30, [sp], 48
	.cfi_remember_state
	.cfi_restore 30
	.cfi_restore 29
	.cfi_restore 21
	.cfi_restore 22
	.cfi_restore 19
	.cfi_restore 20
	.cfi_def_cfa_offset 0
	ret
.L172:
	.cfi_restore_state
	adrp	x20, stderr
	adrp	x1, .LC28
	ldr	x2, [x19]
	add	x1, x1, :lo12:.LC28
	ldr	x0, [x20, #:lo12:stderr]
	bl	fprintf
	ldr	x2, [x19]
	adrp	x1, .LC29
	ldr	x0, [x20, #:lo12:stderr]
	add	x1, x1, :lo12:.LC29
	bl	fprintf
	b	.L164
.L171:
	ldp	x21, x0, [x1, 8]
	mov	w2, 10
	mov	x1, 0
	bl	strtol
	mov	w22, w0
	cmp	w0, 0
	bgt	.L163
	adrp	x1, stderr
	adrp	x0, .LC27
	mov	x2, 41
	add	x0, x0, :lo12:.LC27
	ldr	x3, [x1, #:lo12:stderr]
	mov	x1, 1
	bl	fwrite
	b	.L164
	.cfi_endproc
.LFE29:
	.size	main, .-main
	.section	.rodata.cst8,"aM",@progbits,8
	.align	3
.LC25:
	.word	-536870912
	.word	1058682594
	.ident	"GCC: (GNU) 14.1.0"
	.section	.note.GNU-stack,"",@progbits
