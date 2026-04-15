#include <stdint.h>
#include <stdlib.h>
#include "moonbit.h"

static const int32_t *gv_qsort_ranks = NULL;
static const int32_t *gv_qsort_orders = NULL;

static int gv_qsort_rank_cmp(const void *lhs, const void *rhs) {
  const int32_t left = *(const int32_t *)lhs;
  const int32_t right = *(const int32_t *)rhs;
  const int32_t left_rank = gv_qsort_ranks[left];
  const int32_t right_rank = gv_qsort_ranks[right];
  if (left_rank < right_rank) {
    return -1;
  }
  if (left_rank > right_rank) {
    return 1;
  }
  const int32_t left_order = gv_qsort_orders[left];
  const int32_t right_order = gv_qsort_orders[right];
  if (left_order < right_order) {
    return -1;
  }
  if (left_order > right_order) {
    return 1;
  }
  return 0;
}

MOONBIT_FFI_EXPORT void gv_qsort_indices_by_ranks(
  int32_t *indices,
  int32_t *ranks,
  int32_t *orders,
  int32_t len
) {
  if (indices == NULL || ranks == NULL || orders == NULL || len <= 1) {
    return;
  }
  gv_qsort_ranks = ranks;
  gv_qsort_orders = orders;
  qsort(indices, (size_t)len, sizeof(int32_t), gv_qsort_rank_cmp);
  gv_qsort_ranks = NULL;
  gv_qsort_orders = NULL;
}
