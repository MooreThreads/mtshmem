/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2018-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#include "coll_test.h"

int main(int argc, char *argv[]) {
    int status = 0;
    int mype;
    size_t size = 1;
    struct timeval t_start, t_stop;
    float ms = 0;
    double latency_value;
    musaEvent_t start_event, stop_event;
    musaStream_t stream;

    read_args(argc, argv);

    init_wrapper(&argc, &argv);

    mype = nvshmem_my_pe();
#ifdef _NVSHMEM_DEBUG
    int npes = nvshmem_n_pes();
#endif
    MUSA_CHECK(musaStreamCreateWithFlags(&stream, musaStreamNonBlocking));
    MUSA_CHECK(musaEventCreate(&start_event));
    MUSA_CHECK(musaEventCreate(&stop_event));

    DEBUG_PRINT("SHMEM: [%d of %d] hello shmem world! \n", mype, npes);

    for (size_t iter = 0; iter < iters + warmup_iters; iter++) {
        if (iter == warmup_iters) MUSA_CHECK(musaEventRecord(start_event, stream));

        nvshmemx_team_sync_on_stream(NVSHMEM_TEAM_WORLD, stream);
    }
    MUSA_CHECK(musaEventRecord(stop_event, stream));
    MUSA_CHECK(musaStreamSynchronize(stream));
    MUSA_CHECK(musaEventElapsedTime(&ms, start_event, stop_event));

    if (!mype) {
        latency_value = (ms / iters) * 1000;
        print_table_basic("sync_on_stream", "None", "size (Bytes)", "latency", "us", '-', &size,
                          &latency_value, 1);
    }

    nvshmem_barrier_all();

    MUSA_CHECK(musaStreamDestroy(stream));
    MUSA_CHECK(musaEventDestroy(start_event));
    MUSA_CHECK(musaEventDestroy(stop_event));

    finalize_wrapper();

    return status;
}
