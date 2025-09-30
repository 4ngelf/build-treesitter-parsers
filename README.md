# Build treesitter parsers

[![Compile parsers](https://github.com/4ngelf/build-treesitter-parsers/actions/workflows/package_parsers.yaml/badge.svg)](https://github.com/4ngelf/build-treesitter-parsers/actions/workflows/package_parsers.yaml)

## Install

1. [Download release] for current system
2. Extract contents on `vim.fn.stdpath("data") .. "/site"`

```bash
cd "${XDG_DATA_HOME}/nvim/site"
tar -I zstd -xf parsers-x86_64-linux.tar.zst
```

[Download release]: https://github.com/4ngelf/build-treesitter-parsers/releases/latest
