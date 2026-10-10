/*
 * Copyright (c) 2026, Moore Threads Technology Co., Ltd. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * Coverage example: nvshmem_team_split_strided and nvshmem_team_split_2d.
 * Creates teams from NVSHMEM_TEAM_WORLD, then destroys them.
 */
#include <stdio.h>
#include "nvshmem.h"
#include "nvshmemx.h"

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    nvshmem_init();

    int npes = nvshmem_n_pes();
    int mype = nvshmem_my_pe();
    int mype_node = nvshmem_team_my_pe(NVSHMEMX_TEAM_NODE);
    musaSetDevice(mype_node);
    (void)nvshmem_malloc(1); /* ensure symmetric heap / init complete before team APIs */

    /* --- nvshmem_team_split_strided: one team containing all PEs (stride 1) --- */
    nvshmem_team_t team_strided = NVSHMEM_TEAM_INVALID;
    int ret = nvshmem_team_split_strided(NVSHMEM_TEAM_WORLD, 0, 1, npes, NULL, 0, &team_strided);
    if (ret != 0) {
        fprintf(stderr, "PE %d: nvshmem_team_split_strided failed (ret=%d)\n", mype, ret);
        nvshmem_finalize();
        return 1;
    }
    if (team_strided != NVSHMEM_TEAM_INVALID) {
        int team_pe = nvshmem_team_my_pe(team_strided);
        int team_n = nvshmem_team_n_pes(team_strided);
        nvshmem_team_config_t config;
        nvshmem_team_get_config(team_strided, &config);
        int world_pe = nvshmem_team_translate_pe(team_strided, team_pe, NVSHMEM_TEAM_WORLD);
        (void)world_pe;
        nvshmem_team_destroy(team_strided);
        if (mype == 0) {
            printf("team_split_strided: team had %d PEs (my_pe=%d)\n", team_n, team_pe);
        }
    }

    /* --- nvshmem_team_split_2d: split world into 2D grid (e.g. xrange=2 for 2 columns) --- */
    int xrange = (npes >= 2) ? 2 : 1;
    nvshmem_team_t xaxis_team = NVSHMEM_TEAM_INVALID;
    nvshmem_team_t yaxis_team = NVSHMEM_TEAM_INVALID;
    ret = nvshmem_team_split_2d(NVSHMEM_TEAM_WORLD, xrange, NULL, 0, &xaxis_team, NULL, 0, &yaxis_team);
    if (ret != 0) {
        fprintf(stderr, "PE %d: nvshmem_team_split_2d failed (ret=%d)\n", mype, ret);
        nvshmem_finalize();
        return 1;
    }
    if (xaxis_team != NVSHMEM_TEAM_INVALID) {
        nvshmem_team_destroy(xaxis_team);
    }
    if (yaxis_team != NVSHMEM_TEAM_INVALID) {
        nvshmem_team_destroy(yaxis_team);
    }
    if (mype == 0) {
        printf("team_split_2d: xrange=%d done\n", xrange);
    }

    nvshmem_finalize();
    return 0;
}
