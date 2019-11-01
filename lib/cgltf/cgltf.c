#define CGLTF_IMPLEMENTATION
#include "cgltf.h"

void cgltf_print_struct_sizes() {
    printf("Options %zu\n", sizeof(cgltf_options));
    printf("Data %zu\n", sizeof(cgltf_data));
    printf("Accessor %zu\n", sizeof(cgltf_accessor));
    printf("  component_type: %zu\n", offsetof(cgltf_accessor, component_type));
	printf("  normalized: %zu\n", offsetof(cgltf_accessor, normalized));
	printf("  type: %zu\n", offsetof(cgltf_accessor, type));
	printf("  offset: %zu\n", offsetof(cgltf_accessor, offset));
	printf("  count: %zu\n", offsetof(cgltf_accessor, count));
	printf("  stride: %zu\n", offsetof(cgltf_accessor, stride));
	printf("  buffer_view: %zu\n", offsetof(cgltf_accessor, buffer_view));
	printf("  has_min: %zu\n", offsetof(cgltf_accessor, has_min));
	printf("  min: %zu\n", offsetof(cgltf_accessor, min));
	printf("  has_max: %zu\n", offsetof(cgltf_accessor, has_max));
	printf("  max: %zu\n", offsetof(cgltf_accessor, max));
	printf("  is_sparse: %zu\n", offsetof(cgltf_accessor, is_sparse));
	printf("  sparse: %zu\n", offsetof(cgltf_accessor, sparse));
	printf("  extras: %zu\n", offsetof(cgltf_accessor, extras));
    printf("Accessor_Sparse %zu\n", sizeof(cgltf_accessor_sparse));
    printf("Attribute %zu\n", sizeof(cgltf_attribute));
    printf("Primitive %zu\n", sizeof(cgltf_primitive));
    printf("Extras %zu\n", sizeof(cgltf_extras));
}
