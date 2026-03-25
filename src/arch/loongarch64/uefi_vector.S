/* ZBM 在已加载内核映像 [min_paddr, max_end) 内按 8 字节步进扫描 magic 0x55454649 ("UEFI")。 */
.section .uefi_vector, "a"
.align 8
.global uefi_vector
.type uefi_vector, @object
uefi_vector:
	.word 0x55454649
	.word 0
	.dword kernel_main
	.dword stack_top
