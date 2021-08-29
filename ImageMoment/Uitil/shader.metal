#include <metal_stdlib>
#include <metal_simdgroup>
#include "shader_type.h"

using namespace metal;

#define threadGroupXsize    14  // 横幅が448なら14(=448/32)

kernel void group_max(texture2d<half, access::read> inTexture [[ texture(0) ]],
                      device MomentElement* output_array [[ buffer(1) ]],
                      uint2 position [[thread_position_in_grid]],
                      uint2 group_pos [[threadgroup_position_in_grid]],
                      uint simd_group_index [[simdgroup_index_in_threadgroup]],
                      uint thread_index [[thread_index_in_simdgroup]])
{
    // 1Thread Groupに32のSIMD groupがあるのでその各々の計算結果を格納するメモリを確保
    threadgroup MomentElement simd_sum_array[32];

    // 各スレッドのinput値は`0(黒)`画素を処理対象とする
    bool input = inTexture.read(position).r;
    int binary = !input;
    
    // simd group毎のモーメントを求める
    int i = position.x;
    int j = position.y;
    int m00 = simd_sum(binary);
    int m10 = simd_sum(binary * i);
    int m01 = simd_sum(binary * j);
    // 合計を一時保存
    simd_sum_array[simd_group_index].m00 = m00;
    simd_sum_array[simd_group_index].m10 = m10;
    simd_sum_array[simd_group_index].m01 = m01;

    // Thread Group内のすべてのスレッドの合計の計算＆一時保存を待つ
    threadgroup_barrier(mem_flags::mem_threadgroup);
    // thread group毎のモーメントを求める
    // 1つのSIMD Groupにで32スレッドあるので、１つのSIMD Groupのみで処理。
    if (simd_group_index == 0) {
        output_array[group_pos.y * threadGroupXsize + group_pos.x].m00 = simd_sum(simd_sum_array[thread_index].m00);
        output_array[group_pos.y * threadGroupXsize + group_pos.x].m10 = simd_sum(simd_sum_array[thread_index].m10);
        output_array[group_pos.y * threadGroupXsize + group_pos.x].m01 = simd_sum(simd_sum_array[thread_index].m01);
    }
}
