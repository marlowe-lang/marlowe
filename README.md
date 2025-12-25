<h2 align="center">
  <a href="" target="blank_">
    <img src="./doc/image/logo.svg" alt="Logo" height="75">
  </a>
  <br>
  Marlowe Language Specifications
</h2>
  <p align="center">
    <a href="https://github.com/input-output-hk/marlowe/releases"><img src="https://img.shields.io/github/v/release/input-output-hk/marlowe?style=for-the-badge" /></a>
  </p>
<div align="center">
  <a href=""><img src="https://img.shields.io/badge/stability-beta-33bbff.svg" alt="Beta"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg"></a>
  <a href="https://discord.com/invite/cmveaxuzBn"><img src="https://img.shields.io/discord/826816523368005654?label=Chat%20on%20Discord"></a>
  <a href="https://iohk.zendesk.com/hc/en-us/requests/new"><img src="https://img.shields.io/badge/Support-orange"></a>

</div>

> [!IMPORTANT] 
> This Marlowe repository will soon be moved to https://github.com/marlowe-lang. The new repositories will be administered by an independent vehicle, a not-for-profit organization currently being set up by the transition team.<br> 
> This will allow us to ensure community representation and stewardship. Future developments and support for Marlowe are transitioning to a community-driven model initially led by [Simon Thompson](https://github.com/simonjohnthompson), [Nicolas Henin](https://github.com/nhenin) and [Tomasz Rybarczyk](https://github.com/paluh). <br>
> See [here](https://github.com/marlowe-lang/.github/blob/main/profile/transition.md) for details. 


This repository contains the specification of Marlowe, a domain-specific language (DSL) for describing financial smart contracts that can be enforced by scripts deployed on a blockchain, as well as some tools for analysing and simulating the execution of contracts written in the DSL. To use Marlowe on the cardano blockchain please refer to the [marlowe-cardano](https://github.com/input-output-hk/marlowe-cardano) repository

## Learning about Marlowe and its ecosystem

The [Marlowe tutorials](https://docs.marlowe.iohk.io/tutorials) introduce Marlowe and the Marlowe Playground.

The [Marlowe website](https://marlowe.iohk.io/) and [Marlowe docs site](https://docs.marlowe.iohk.io/docs/introduction) explain what Marlowe is and the different tools available.

## Versions of Marlowe

The `master` branch contains the latest version of Marlowe, version `3`.

An earlier version of Marlowe is described in a [paper](https://iohk.io/research/papers/#2WHKDRA8) that was presented at ISoLA 2018. This version is tagged `v1.3` and a minor update on this is tagged `v1.3.1`.

## Developer environment

This repository uses `nix` and `nix-flakes` to provide a reproducible developer environment to all users. Follow the instructions to [install](https://nixos.org/download.html) the nix package manager on your OS and then [use nix to install nix-flakes](https://wiki.nixos.org/wiki/Flakes#Installing_flakes).

Once both tools are installed, download the repository and get in the development environment using

```bash
$ git clone git@github.com:input-output-hk/marlowe.git
$ cd marlowe
$ nix develop .
```

### Isabelle proofs

To Build the tests, you can run the following command inside the development environment.

```bash
[nix-develop] $ build-marlowe-proofs
```

To open the Isabelle IDE to modify or explore the proofs, use the following command

```bash
[nix-develop] $ edit-marlowe-proofs
```

To generate the specification and cheatsheet pdfs you can use the following command:
```bash
[nix-develop] $ build-marlowe-docs
```

the results will be available in the `papers` folder.


## Restriction on Pull Requests

If you are proposing a change to the Marlowe domain-specific language (DSL), pursue the [Marlowe Improvement Proposal (MIP)](https://github.com/input-output-hk/MIPs) process by starting a [MIP discussion](https://github.com/input-output-hk/MIPs/discussions) of the proposed change. **Pull requests for DSL changes will be rejected unless they have previously been approved via the MIP process.**
