# MTSHMEM

MTSHMEM is a parallel programming interface based on OpenSHMEM that provides efficient and scalable communication for Moore Threads GPU clusters. MTSHMEM creates a global address space for data that spans the memory of multiple GPUs and can be accessed with fine-grained GPU-initiated operations, CPU-initiated operations, and operations on MUSA streams.

MTSHMEM is derived from the [NVSHMEM project](https://github.com/NVIDIA/nvshmem) developed by NVIDIA Corporation and other contributors. It includes modifications made for Moore Threads GPUs and the MUSA software stack.

## Dependencies and support

### Required dependencies

- Two or more Moore Threads GPUs (S5000);
- MUSA Driver and MUSA Toolkit;
- CMake and a supported C/C++ toolchain;
- A compatible process launcher, such as Open MPI or Hydra.

Refer to the official documentation for the MUSA SDK components, installation instructions, and download information:

- [MUSA SDK introduction](https://docs.mthreads.com/musa-sdk/musa-sdk-doc-online/introduction)
- [MUSA SDK installation guide](https://docs.mthreads.com/musa-sdk/musa-sdk-doc-online/install_guide)

Install the MUSA Toolkit and driver according to the official documentation before building MTSHMEM.

### Optional dependencies

- `mt_peermem`: May be required by some peer-memory or network paths. It is packaged with the MUSA SDK, and the default build does not require it.
- `mtgdrcpy`: Optional dependency for selected IBGDA memory-mapping paths. If `NVSHMEM_IBGDA_NIC_HANDLER=cpu` is used, `mtgdrcpy` must be installed and MTSHMEM must be built with `-DNVSHMEM_USE_GDRCOPY=1`.

## Build from source

The following steps assume that the MUSA Toolkit has been installed according to the official documentation:

```bash
export MUSA_HOME=/usr/local/musa

cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_MUSA_ARCHITECTURES=mp_31 \
  -DNVSHMEM_USE_GDRCOPY=0 \
  -DNVSHMEM_BUILD_EXAMPLES=1 \
  -DNVSHMEM_BUILD_TESTS=0

cmake --build build --parallel
```

The repository also provides a build shortcut for the current MUSA development configuration:

```bash
bash build.sh
```

For other environments, use the explicit CMake command and adjust the MUSA architecture, MPI, UCX, and optional dependency settings as needed.

## Install

The default installation prefix is `/usr/local/mtshmem`:

```bash
sudo cmake --install build
```

The installation script uses the same default prefix:

```bash
sudo ./install.sh --install
```

Uninstall from the default prefix with:

```bash
sudo ./install.sh --uninstall
```

After installation, make the binaries and libraries available in the current shell:

```bash
export PATH="/usr/local/mtshmem/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/mtshmem/lib:${LD_LIBRARY_PATH}"
```

## Minimal verification

Confirm that the installation is available, then run the basic example. The exact `nvshmrun` launcher arguments depend on the configured bootstrap and MPI environment:

```bash
export PATH="/usr/local/mtshmem/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/mtshmem/lib:${LD_LIBRARY_PATH}"

nvshmrun -n 2 /usr/local/mtshmem/bin/examples/hello
```

With an MPI environment, run:

```bash
mpirun -n 2 /usr/local/mtshmem/bin/examples/mpi-based-init
```

## Examples and perftest

The repository includes examples and perftest sources for development and validation:

- `examples/`: C++/MUSA communication examples;
- `perftest/`: performance test sources and runners.

These components require their respective optional dependencies and supported hardware.

## Contributing

See the [Contributing Guide](CONTRIBUTING.md) before opening a pull request. Commits require a
Developer Certificate of Origin (DCO) sign-off (`git commit -s`).

## License

MTSHMEM is licensed under the Apache License 2.0. Read [`License.txt`](License.txt) and [`NOTICE`](NOTICE), including the third-party license notices distributed with the source.
