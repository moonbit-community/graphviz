// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

#include <stdint.h>
#include <stdlib.h>
#include "moonbit.h"

typedef struct { int32_t index; int32_t priority; } route_sort_entry;
static int compare_route_entries(const void *a, const void *b) {
  int32_t x = ((const route_sort_entry *)a)->priority;
  int32_t y = ((const route_sort_entry *)b)->priority;
  return (x > y) - (x < y);
}
MOONBIT_FFI_EXPORT void gv_concentrated_route_sort(int32_t *indices, int32_t *priorities, int32_t length) {
  if (length < 2) return;
  route_sort_entry *entries = malloc((size_t)length * sizeof(*entries));
  if (!entries) abort();
  for (int32_t i = 0; i < length; ++i) entries[i] = (route_sort_entry){i, priorities[i]};
  qsort(entries, (size_t)length, sizeof(*entries), compare_route_entries);
  for (int32_t i = 0; i < length; ++i) indices[i] = entries[i].index;
  free(entries);
}
