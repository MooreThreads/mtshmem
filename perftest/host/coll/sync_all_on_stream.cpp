/*
 * This file has been modified by Moore Threads Technology Co., Ltd.
 * Modifications for MTSHMEM are Copyright (c) 2025-2026 Moore Threads Technology Co., Ltd.
 */

/*
 * Copyright (c) 2018-2026, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

#include "coll_test.h"
int coll_max_iters = MAX_ITERS;

int main(int c, char *v[]) {
    int status = 0;
    int mype;
    size_t size = 1;
    double latency_value;
    int iters = MAX_ITERS;
    int skip = MAX_SKIP;
    struct timeval t_start, t_stop;
    float ms = 0;
    musaEvent_t start_event, stop_event;
    musaStream_t stream;

    init_wrapper(&c, &v);

    mype = nvshmem_my_pe();
#ifdef _NVSHMEM_DEBUG
    int npes = nvshmem_n_pes();
#endif
    MUSA_CHECK(musaStreamCreateWithFlags(&stream, musaStreamNonBlocking));
    MUSA_CHECK(musaEventCreate(&start_event));
    MUSA_CHECK(musaEventCreate(&stop_event));

    DEBUG_PRINT("SHMEM: [%d of %d] hello shmem world! \n", mype, npes);

    for (iters = 0; iters < coll_max_iters + skip; iters++) {
        if (iters == skip) MUSA_CHECK(musaEventRecord(start_event, stream));

        nvshmemx_sync_all_on_stream(stream);
    }
    MUSA_CHECK(musaEventRecord(stop_event, stream));
    MUSA_CHECK(musaStreamSynchronize(stream));
    MUSA_CHECK(musaEventElapsedTime(&ms, start_event, stop_event));
    if (!mype) {
        latency_value = (ms / coll_max_iters) * 1000;
        print_table_basic("sync_all_on_stream", "None", "size (Bytes)", "latency", "us", '-', &size,
                          &latency_value, 1);
    }

    nvshmem_barrier_all();

    MUSA_CHECK(musaStreamDestroy(stream));
    MUSA_CHECK(musaEventDestroy(start_event));
    MUSA_CHECK(musaEventDestroy(stop_event));

    finalize_wrapper();

    return status;
}
