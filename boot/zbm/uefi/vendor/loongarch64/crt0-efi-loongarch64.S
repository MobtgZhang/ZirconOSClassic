/*
 * crt0-efi-loongarch64.S - PE/COFF header for LoongArch64 EFI applications
 *
 * Copyright (C) 2021 Loongson Technology Corporation Limited. <zhoumingtao@loongson.cn>
 * Copyright (C) 2014 Linaro Ltd. <ard.biesheuvel@linaro.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice and this list of conditions, without modification.
 * 2. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * Alternatively, this software may be distributed under the terms of the
 * GNU General Public License as published by the Free Software Foundation;
 * either version 2 of the License, or (at your option) any later version.
 *
 * Classic 修改：bl _entry → bl efi_main（Zig 导出），无需 libgnuefi。
 */

	.text
	.align		12
	.globl	_start
	.type	_start, @function
_start:
	addi.d	  $sp, $sp, -24
	st.d	  $ra, $sp, 0
	st.d	  $a0, $sp, 8
	st.d 	  $a1, $sp, 16

	move	  $a2, $a0		// a2: ImageHandle
	move	  $a3, $a1 		// a3: SystemTable
	la.local  $a0, ImageBase	// a0: ImageBase
	la.local  $a1, _DYNAMIC		// a1: DynamicSection
	bl        _relocate
	bnez	  $a0, 0f

	ld.d	  $a0, $sp, 8
	ld.d	  $a1, $sp, 16
	/*
	 * UEFI 固件常以 EUEN=0 进入应用，未打开 FPU/LSX/LASX；Zig/LLVM 仍可能生成对应指令，
	 * 在 GetInfo 等路径上触发 #INE。与 Linux 一致写 CSR EUEN（0x2）：FPEN|LSXEN|LASXEN。
	 * LOONGARCH_CSR_EUEN=0x2，见 arch/loongarch/include/asm/loongarch.h
	 */
	li.d	  $t0, 7
	csrwr	  $t0, 0x2
	bl        efi_main

0:	ld.d	  $ra, $sp, 0
	addi.d	  $sp, $sp, 24
	jr	      $ra

 	.data
dummy:	.4byte	0

#define IMAGE_REL_ABSOLUTE	0
 	.section .reloc, "a"
label1:
	.4byte	dummy-label1
	.4byte	12
	.2byte	(IMAGE_REL_ABSOLUTE<<12) +  0
	.2byte	(IMAGE_REL_ABSOLUTE<<12) +  0

#if defined(__ELF__) && defined(__linux__)
	.section .note.GNU-stack,"",%progbits
#endif
