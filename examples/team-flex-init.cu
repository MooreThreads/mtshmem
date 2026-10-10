/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * Smoke test: nvshmemx_team_get_uniqueid + nvshmemx_team_init (UID flexible team).
 */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "nvshmem.h"
#include "nvshmemx.h"

#undef MUSA_CHECK
#define MUSA_CHECK(stmt)                                                          \
    do {                                                                          \
        musaError_t result = (stmt);                                              \
        if (musaSuccess != result) {                                              \
            fprintf(stderr, "[%s:%d] musa failed with %s\n", __FILE__, __LINE__, \
                    musaGetErrorString(result));                                  \
            exit(-1);                                                             \
        }                                                                         \
    } while (0)

enum collective_api {
    COLLECTIVE_API_TYPED = 0,
    COLLECTIVE_API_MEM,
};

enum collective_scope {
    COLLECTIVE_SCOPE_THREAD = 0,
    COLLECTIVE_SCOPE_WARP,
    COLLECTIVE_SCOPE_BLOCK,
};

static_assert(sizeof(__half) == 2, "MUSA half must remain a 16-bit public type");
static_assert(sizeof(__mt_bfloat16) == 2, "MUSA bfloat16 must remain a 16-bit public type");

__global__ void team_sync_kernel(nvshmem_team_t team) { nvshmem_team_sync(team); }

__global__ void team_typed_collectives_kernel(nvshmem_team_t team, int *broadcast_dest,
                                              const int *broadcast_source,
                                              uint16_t *fcollect_dest,
                                              const uint16_t *fcollect_source, int scope) {
    if (scope == COLLECTIVE_SCOPE_BLOCK) {
        nvshmemx_int_broadcast_block(team, broadcast_dest, broadcast_source, 1, 1);
        nvshmemx_uint16_fcollect_block(team, fcollect_dest, fcollect_source, 1);
    } else if (scope == COLLECTIVE_SCOPE_WARP) {
        nvshmemx_int_broadcast_warp(team, broadcast_dest, broadcast_source, 1, 1);
        nvshmemx_uint16_fcollect_warp(team, fcollect_dest, fcollect_source, 1);
    } else if (threadIdx.x == 0) {
        nvshmem_int_broadcast(team, broadcast_dest, broadcast_source, 1, 1);
        nvshmem_uint16_fcollect(team, fcollect_dest, fcollect_source, 1);
    }
}

__global__ void team_mem_collectives_kernel(nvshmem_team_t team, int *broadcast_dest,
                                            const int *broadcast_source, uint16_t *fcollect_dest,
                                            const uint16_t *fcollect_source) {
    if (threadIdx.x == 0) {
        nvshmem_broadcastmem(team, broadcast_dest, broadcast_source, sizeof(int), 1);
        nvshmem_fcollectmem(team, fcollect_dest, fcollect_source, sizeof(uint16_t));
    }
}

__global__ void team_reducescatter_kernel(nvshmem_team_t team, int *dest, const int *source) {
    if (threadIdx.x == 0) {
        nvshmem_int_sum_reducescatter(team, dest, source, 1);
    }
}

static int run_split_strided_lifecycle(int mype, int pe_start, int pe_stride, int pe_size,
                                       const char *label) {
    int test_status = 0;
    const bool is_member =
        mype >= pe_start && mype < pe_start + pe_stride * pe_size &&
        ((mype - pe_start) % pe_stride == 0);

    for (int iteration = 0; iteration < 4; iteration++) {
        nvshmem_team_t team = NVSHMEM_TEAM_INVALID;
        int ret = nvshmem_team_split_strided(NVSHMEM_TEAM_WORLD, pe_start, pe_stride, pe_size, NULL,
                                             0, &team);
        if (ret != 0) {
            fprintf(stderr, "PE %d: %s split failed at iteration %d (ret=%d)\n", mype, label,
                    iteration, ret);
            test_status = 1;
        } else if (is_member) {
            int expected_my_pe = (mype - pe_start) / pe_stride;
            if (team == NVSHMEM_TEAM_INVALID || nvshmem_team_n_pes(team) != pe_size ||
                nvshmem_team_my_pe(team) != expected_my_pe) {
                fprintf(stderr, "PE %d: %s metadata mismatch at iteration %d\n", mype, label,
                        iteration);
                test_status = 1;
            } else {
                nvshmem_team_sync(team);
                team_sync_kernel<<<1, 1>>>(team);
                MUSA_CHECK(musaGetLastError());
                MUSA_CHECK(musaDeviceSynchronize());
                nvshmem_team_destroy(team);
            }
        } else if (team != NVSHMEM_TEAM_INVALID) {
            fprintf(stderr, "PE %d: %s unexpectedly returned team %d at iteration %d\n", mype,
                    label, team, iteration);
            test_status = 1;
        }
        nvshmem_barrier_all();
    }

    return test_status;
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    nvshmem_init();

    int npes = nvshmem_n_pes();
    int mype = nvshmem_my_pe();
    int mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);
    MUSA_CHECK(musaSetDevice(mype_node));
    nvshmem_barrier_all();

    if (npes < 4) {
        if (mype == 0) {
            printf("team-flex-init: need >= 4 PEs, got %d (skipped)\n", npes);
        }
        nvshmem_finalize();
        return 0;
    }

    int test_status = 0;
    test_status |= run_split_strided_lifecycle(mype, 0, 1, 1, "single-PE team");
    test_status |=
        run_split_strided_lifecycle(mype, 0, 2, (npes + 1) / 2, "even-PE strided team");

    nvshmemx_team_uniqueid_t uid;
    nvshmemx_team_get_uniqueid(&uid);

    nvshmemx_team_uniqueid_t *uid_buf =
        (nvshmemx_team_uniqueid_t *)nvshmem_malloc(sizeof(*uid_buf));
    if (uid_buf == NULL) {
        fprintf(stderr, "PE %d: nvshmem_malloc failed for uid buffer\n", mype);
        nvshmem_finalize();
        return 1;
    }

    if (mype == 0) {
        MUSA_CHECK(musaMemcpy(uid_buf, &uid, sizeof(uid), musaMemcpyHostToDevice));
    }
    nvshmem_barrier_all();
    nvshmem_broadcastmem(NVSHMEM_TEAM_WORLD, uid_buf, uid_buf, sizeof(*uid_buf), 0);
    MUSA_CHECK(musaMemcpy(&uid, uid_buf, sizeof(uid), musaMemcpyDeviceToHost));
    nvshmem_barrier_all();
    nvshmem_free(uid_buf);

    const int team_npes = 3;
    int *broadcast_source = (int *)nvshmem_malloc(sizeof(*broadcast_source));
    int *broadcast_dest = (int *)nvshmem_malloc(sizeof(*broadcast_dest));
    uint16_t *fcollect_source = (uint16_t *)nvshmem_malloc(sizeof(*fcollect_source));
    uint16_t *fcollect_dest =
        (uint16_t *)nvshmem_malloc(team_npes * sizeof(*fcollect_dest));
    int *reducescatter_source = (int *)nvshmem_malloc(team_npes * sizeof(*reducescatter_source));
    int *reducescatter_dest = (int *)nvshmem_malloc(sizeof(*reducescatter_dest));
    if (broadcast_source == NULL || broadcast_dest == NULL || fcollect_source == NULL ||
        fcollect_dest == NULL || reducescatter_source == NULL || reducescatter_dest == NULL) {
        fprintf(stderr, "PE %d: nvshmem_malloc failed for collective buffers\n", mype);
        nvshmem_global_exit(1);
    }
    musaStream_t stream;
    MUSA_CHECK(musaStreamCreate(&stream));

    /* PEs {0,1,3} form a non-strided flexible team when npes >= 4. */
    int my_pe_in_team = -1;
    if (mype == 0) {
        my_pe_in_team = 0;
    } else if (mype == 1) {
        my_pe_in_team = 1;
    } else if (mype == 3) {
        my_pe_in_team = 2;
    }

    if (my_pe_in_team >= 0) {
        for (int iteration = 0; iteration < 3; iteration++) {
            nvshmem_team_t flex_team = NVSHMEM_TEAM_INVALID;
            nvshmem_team_config_t config = NVSHMEMI_TEAM_CONFIG_INITIALIZER;
            config.version = NVSHMEMI_TEAM_CONFIG_VERSION_2_IDENTIFIER;
            config.uniqueid = uid;

            int ret = nvshmemx_team_init(&flex_team, &config, 0, team_npes, my_pe_in_team);
            if (ret != 0) {
                fprintf(stderr, "PE %d: nvshmemx_team_init failed at iteration %d (ret=%d)\n",
                        mype, iteration, ret);
                nvshmem_global_exit(1);
            }
            nvshmem_team_sync(flex_team);
            team_sync_kernel<<<1, 1>>>(flex_team);
            MUSA_CHECK(musaGetLastError());
            MUSA_CHECK(musaDeviceSynchronize());

            int broadcast_value = 1000 + mype;
            uint16_t fcollect_value = (uint16_t)mype;
            int reducescatter_values[team_npes] = {mype + 1, mype + 1, mype + 1};
            MUSA_CHECK(musaMemcpy(broadcast_source, &broadcast_value, sizeof(broadcast_value),
                                  musaMemcpyHostToDevice));
            MUSA_CHECK(musaMemcpy(fcollect_source, &fcollect_value, sizeof(fcollect_value),
                                  musaMemcpyHostToDevice));
            MUSA_CHECK(musaMemcpy(reducescatter_source, reducescatter_values,
                                  sizeof(reducescatter_values), musaMemcpyHostToDevice));

            const char *api_names[] = {"typed", "mem"};
            const char *scope_names[] = {"thread", "warp", "block"};
            const uint16_t expected_fcollect[] = {0, 1, 3};
            musaDeviceProp prop;
            MUSA_CHECK(musaGetDeviceProperties(&prop, mype_node));
            const int block_threads[] = {1, prop.warpSize, 128};

            for (int scope = COLLECTIVE_SCOPE_THREAD; scope <= COLLECTIVE_SCOPE_BLOCK; scope++) {
                for (int api = COLLECTIVE_API_TYPED; api <= COLLECTIVE_API_MEM; api++) {
                    /* MUSA 5.2 cannot yet compile raw mem warp/block instantiations at -O3. */
                    if (api == COLLECTIVE_API_MEM && scope != COLLECTIVE_SCOPE_THREAD) continue;

                    int actual_broadcast = -1;
                    uint16_t actual_fcollect[team_npes] = {};
                    MUSA_CHECK(musaMemset(broadcast_dest, 0xff, sizeof(*broadcast_dest)));
                    MUSA_CHECK(musaMemset(fcollect_dest, 0xff,
                                          team_npes * sizeof(*fcollect_dest)));

                    if (api == COLLECTIVE_API_MEM) {
                        team_mem_collectives_kernel<<<1, 1>>>(
                            flex_team, broadcast_dest, broadcast_source, fcollect_dest,
                            fcollect_source);
                    } else {
                        team_typed_collectives_kernel<<<1, block_threads[scope]>>>(
                            flex_team, broadcast_dest, broadcast_source, fcollect_dest,
                            fcollect_source, scope);
                    }
                    MUSA_CHECK(musaGetLastError());
                    MUSA_CHECK(musaDeviceSynchronize());
                    MUSA_CHECK(musaMemcpy(&actual_broadcast, broadcast_dest,
                                          sizeof(actual_broadcast), musaMemcpyDeviceToHost));
                    MUSA_CHECK(musaMemcpy(actual_fcollect, fcollect_dest, sizeof(actual_fcollect),
                                          musaMemcpyDeviceToHost));

                    if (actual_broadcast != 1001) {
                        fprintf(stderr,
                                "PE %d: %s %s broadcast got %d, expected 1001 on flexible team\n",
                                mype, scope_names[scope], api_names[api], actual_broadcast);
                        test_status = 1;
                    }
                    for (int i = 0; i < team_npes; i++) {
                        if (actual_fcollect[i] != expected_fcollect[i]) {
                            fprintf(stderr,
                                    "PE %d: %s %s fcollect[%d] got %u, expected %u on flexible "
                                    "team\n",
                                    mype, scope_names[scope], api_names[api], i,
                                    (unsigned)actual_fcollect[i],
                                    (unsigned)expected_fcollect[i]);
                            test_status = 1;
                        }
                    }
                }
            }

            int actual_broadcast = -1;
            uint16_t actual_fcollect[team_npes] = {};
            MUSA_CHECK(musaMemsetAsync(broadcast_dest, 0xff, sizeof(*broadcast_dest), stream));
            MUSA_CHECK(musaMemsetAsync(fcollect_dest, 0xff,
                                       team_npes * sizeof(*fcollect_dest), stream));
            MUSA_CHECK(musaMemsetAsync(reducescatter_dest, 0xff, sizeof(*reducescatter_dest),
                                       stream));
            nvshmemx_broadcastmem_on_stream(flex_team, broadcast_dest, broadcast_source,
                                            sizeof(int), 1, stream);
            nvshmemx_fcollectmem_on_stream(flex_team, fcollect_dest, fcollect_source,
                                           sizeof(uint16_t), stream);
            nvshmemx_int_sum_reducescatter_on_stream(flex_team, reducescatter_dest,
                                                      reducescatter_source, 1, stream);
            MUSA_CHECK(musaStreamSynchronize(stream));
            MUSA_CHECK(musaMemcpy(&actual_broadcast, broadcast_dest, sizeof(actual_broadcast),
                                  musaMemcpyDeviceToHost));
            MUSA_CHECK(musaMemcpy(actual_fcollect, fcollect_dest, sizeof(actual_fcollect),
                                  musaMemcpyDeviceToHost));
            int actual_reducescatter = -1;
            MUSA_CHECK(musaMemcpy(&actual_reducescatter, reducescatter_dest,
                                  sizeof(actual_reducescatter), musaMemcpyDeviceToHost));
            if (actual_broadcast != 1001) {
                fprintf(stderr,
                        "PE %d: on-stream broadcast got %d, expected 1001 on flexible team\n",
                        mype, actual_broadcast);
                test_status = 1;
            }
            for (int i = 0; i < team_npes; i++) {
                if (actual_fcollect[i] != expected_fcollect[i]) {
                    fprintf(stderr,
                            "PE %d: on-stream fcollect[%d] got %u, expected %u on flexible team\n",
                            mype, i, (unsigned)actual_fcollect[i],
                            (unsigned)expected_fcollect[i]);
                    test_status = 1;
                }
            }
            if (actual_reducescatter != 7) {
                fprintf(stderr,
                        "PE %d: on-stream reducescatter got %d, expected 7 on flexible team\n",
                        mype, actual_reducescatter);
                test_status = 1;
            }

            actual_reducescatter = -1;
            MUSA_CHECK(musaMemset(reducescatter_dest, 0xff, sizeof(*reducescatter_dest)));
            team_reducescatter_kernel<<<1, 1>>>(flex_team, reducescatter_dest,
                                                 reducescatter_source);
            MUSA_CHECK(musaGetLastError());
            MUSA_CHECK(musaDeviceSynchronize());
            MUSA_CHECK(musaMemcpy(&actual_reducescatter, reducescatter_dest,
                                  sizeof(actual_reducescatter), musaMemcpyDeviceToHost));
            if (actual_reducescatter != 7) {
                fprintf(stderr,
                        "PE %d: thread reducescatter got %d, expected 7 on flexible team\n", mype,
                        actual_reducescatter);
                test_status = 1;
            }

            if (mype == 0) {
                printf("team-flex-init: non-strided flexible team iteration %d passed, idx=%d "
                       "n_pes=%d\n",
                       iteration, flex_team, nvshmem_team_n_pes(flex_team));
            }
            nvshmem_team_destroy(flex_team);
        }
    }

    nvshmem_barrier_all();
    MUSA_CHECK(musaStreamDestroy(stream));
    nvshmem_free(broadcast_source);
    nvshmem_free(broadcast_dest);
    nvshmem_free(fcollect_source);
    nvshmem_free(fcollect_dest);
    nvshmem_free(reducescatter_source);
    nvshmem_free(reducescatter_dest);
    nvshmem_finalize();
    return test_status;
}
