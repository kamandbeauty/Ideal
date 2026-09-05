package com.ideal.woomanager.util

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.CreationExtras
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import com.ideal.woomanager.WooApp
import com.ideal.woomanager.data.repository.WooRepository

/** Small factory that supplies the shared [WooRepository] to view models. */
class RepoViewModelFactory(
    private val repository: WooRepository,
    private val creator: (WooRepository) -> ViewModel
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T =
        creator(repository) as T
}

@Composable
inline fun <reified VM : ViewModel> repoViewModel(
    noinline creator: (WooRepository) -> VM
): VM {
    val context = LocalContext.current
    val repo = (context.applicationContext as WooApp).repository
    return viewModel(factory = RepoViewModelFactory(repo) { creator(it) })
}
