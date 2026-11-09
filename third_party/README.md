# Third-party source

The CPU integration target expects the upstream `picorv32.v` file in
`third_party/picorv32/`. Fetch it with:

```sh
bash scripts/get_picorv32.sh
```

Upstream project: https://github.com/YosysHQ/picorv32
Upstream license: ISC; the license text is retained in `PICORV32_COPYING.txt`.
The fetch script prints the checked-out Git commit so the exact core revision
can be recorded with test results. The upstream RTL is not vendored in this
archive because this build environment cannot resolve external package hosts.

## Revision used for the recorded integration test

The project owner fetched and ran the integration test against upstream commit:

`ef203c2b0a3fb793280f5114941416c425c5b461`

To reproduce that exact revision after fetching:

```sh
git -C third_party/picorv32 checkout ef203c2b0a3fb793280f5114941416c425c5b461
```


The upstream PicoRV32 source is intentionally not vendored in this archive. Fetch it with `bash scripts/get_picorv32.sh`; for the recorded validation run, use commit `ef203c2b0a3fb793280f5114941416c425c5b461`. The standalone DMA RTL, Python reference model, firmware, testbenches and documentation are included.
