package com.ideal.woomanager.ui.components

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.ideal.woomanager.util.DateRange

@Composable
fun RangeSelector(
    selected: DateRange,
    onSelect: (DateRange) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        DateRange.entries.forEach { range ->
            FilterChip(
                selected = selected == range,
                onClick = { onSelect(range) },
                label = { Text(range.label) }
            )
        }
    }
}
