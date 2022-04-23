# Copyright 2022 MaBling <akck0918@gmail.com>. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Tells icu to load an external data file rather than rely on the icudata
# being linked directly into the binary.
set(ICU_USE_DATA_FILE ON)

# If true, then this creates a stub data file. This should be disabled if
# a custom data file will be used instead, in order to avoid conflicting
# symbols.
set(ICU_USE_STUB_DATA ON)

# If true, compile icu into a standalone static library. Currently this is
# only useful on Chrome OS.
set(ICU_DISABLE_THIN_ARCHIVE OFF)
