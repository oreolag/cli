<p align="center" style="margin-bottom: 0px;">
  <img src="https://github.com/oreolag/cli/blob/main/cli-removebg.png" 
       align="center" style="width: 200px; height: auto;">
</p>

<h1 align="center">
  Oreol CLI
</h1> 

 <!-- ```odev``` is the CLI for hetero*genious* computing. Building on the Heterogeneous Accelerated Compute Cluster CLI developed at ETH Zurich (see [hdev](https://github.com/fpgasystems/hdev) on GitHub), ```odev``` extends device-centric workflows with [Metaflow](https://metaflow.org) orchestration to help scientists and engineers build and manage real-life AI and ML systems across Slurm and Kubernetes. [Start here](#start-here) to experience the Just Work™ workflows! -->

<!-- ```odev``` is the CLI for hetero*genius* computing. Building on the Heterogeneous Accelerated Compute Cluster CLI developed at ETH Zurich (see [hdev](https://github.com/fpgasystems/hdev) on GitHub), ```odev``` abstracts NUMA-local heterogeneous resources as topology-aware computing units. This dramatically simplifies the deployment and execution of real-world AI, HPC, and ML workloads across modern accelerated computing infrastructures. Combined with integrated community workflows for popular HPC and AI environments such as NCCL, Metaflow, and vLLM, ```odev``` empowers researchers and engineers to build, deploy, and operate reproducible workloads across CPUs, GPUs, FPGAs, storage, and high-performance networking systems. -->

```odev``` is the CLI for hetero*genius* computing. Building on the Heterogeneous Accelerated Compute Cluster CLI developed at ETH Zurich (see [hdev](https://github.com/fpgasystems/hdev) on GitHub), ```odev``` abstracts NUMA-local heterogeneous resources as topology-aware computing units, simplifying deployment while enabling reproducible experimentation and consistent performance baselines through NUMA-aware execution.

Combined with integrated community workflows for popular HPC, ML, and AI environments such as NCCL, Metaflow, and vLLM, ```odev``` empowers researchers and engineers to easily build and run their applications across advanced heterogeneous hardware—including CPUs, GPUs, FPGAs, storage, and high-performance networking systems—to solve real-world problems.

[Start here](#start-here) to configure your heterogeneous computing infrastructure.

<!-- ## Sections
* [Start here](#start-here)
* [Citation](#citation) -->

# Start Here
Follow these steps to set up your `odev` infrastructure and start building topology-aware heterogeneous computing environments.

## Installation
Run the following command on your Linux host (see [Supported Platforms](#supported-platforms)):

```bash
curl -H 'Cache-Control: no-cache' -fsSL https://oreol.ch/cli/install.sh | sudo bash
```

## Supported Platforms
`odev` currently supports Ubuntu-based Linux distributions. Validated environments include:

- Ubuntu
- NVIDIA DGX

Additional Linux distributions may work but are not officially validated yet.

# Citation

[![Zenodo](https://img.shields.io/badge/software%20DOI-10.5281%2Fzenodo.20229347-blue)](https://doi.org/10.5281/zenodo.20229347)
[![ACM](https://img.shields.io/badge/paper%20DOI-10.1145%2F3805700-green)](https://doi.org/10.1145/3805700)

If you use `odev` in your research, development, or publications, please cite the following references:

```bibtex
@misc{moya2026odev,
  author       = {Javier Moya},
  title        = {oreolag/cli: odev},
  howpublished = {Zenodo},
  year         = {2026},
  note         = {\url{https://doi.org/10.5281/zenodo.20229347}},
  doi          = {10.5281/zenodo.20229347}
}
```

```bibtex
@article{moya2025hacc,
  author    = {Javier Moya and Mario Ruiz and Gustavo Alonso},
  title     = {A Development Platform for Managed Heterogeneous Accelerated Compute Clusters: A Case Study on ETH Zurich’s AMD HACC},
  journal   = {ACM Transactions on Reconfigurable Technology and Systems},
  year      = {2025},
  doi       = {10.1145/3805700},
  url       = {https://doi.org/10.1145/3805700}
}
```