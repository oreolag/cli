<p align="center" style="margin-bottom: 0px;">
  <img src="https://github.com/oreolag/cli/blob/main/cli-removebg.png" 
       align="center" style="width: 200px; height: auto;">
</p>

<h1 align="center">
  Oreol CLI
</h1> 

 ```odev``` is the CLI for hetero*genious* computing. Building on the Heterogeneous Accelerated Compute Cluster CLI developed at ETH Zurich (see [hdev](https://github.com/fpgasystems/hdev) on GitHub), ```odev``` extends device-centric workflows with [Metaflow](https://metaflow.org) orchestration to help scientists and engineers build and manage real-life AI and ML systems across Slurm and Kubernetes. [Start here](#start-here) to experience the Just Work™ workflows!

## Sections
* [Start here](#start-here)
* [Citation](#citation)

# Start Here
Install odev with:

```bash
curl -H 'Cache-Control: no-cache' -fsSL https://oreol.ch/cli/install.sh | sudo bash
```

# Citation

<!-- [![DOI](https://zenodo.org/badge/20229347.svg)](https://doi.org/10.5281/zenodo.20229347)
[![Paper](https://img.shields.io/badge/DOI-10.1145%2F3805700-blue)](https://doi.org/10.1145/3805700) -->

[![DOI](https://img.shields.io/badge/DOI-10.5281%2Fzenodo.20229347-blue)](https://doi.org/10.5281/zenodo.20229347)

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