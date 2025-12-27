function clearText() {
	const textarea = document.getElementById('text');
	textarea.value = '';
	textarea.focus();

	const results = document.getElementById('results');
	results.innerHTML = '';
}

document.addEventListener('DOMContentLoaded', function() {
	const textarea = document.getElementById('text');

	textarea.addEventListener('input', function() {
		this.style.height = 'auto';
		this.style.height = Math.max(120, this.scrollHeight) + 'px';
	});
});

function shareToTwitter() {
	const text = 'Webスダチ - Sudachi 形態素解析ツール';
	const url = window.location.href;
	window.open(`https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}`,
			'_blank');
}

function shareToFacebook() {
	const url = window.location.href;
	window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`, '_blank');
}

function copyLink() {
	navigator.clipboard.writeText(window.location.href).then(() => {
		alert('リンクをクリップボードにコピーしました！');
	});
}

function shareNative() {
	if (navigator.share) {
		navigator.share({
			title: 'Webスダチ',
			text: 'Sudachi形態素解析ツール',
			url: window.location.href,
		});
	} else {
		copyLink();
	}
}

document.addEventListener('DOMContentLoaded', function() {
	document.body.addEventListener('htmx:afterSwap', function(evt) {
		if (evt.target.id === 'results') {
			initializeClipboard();
		}
	});
});

function showCopySuccess() {
	const toastElement = document.getElementById('copySuccessToast');
	if (toastElement) {
		const toast = new bootstrap.Toast(toastElement, {
			autohide: true,
			delay: 3000,
		});
		toast.show();
	}
}

function showCopyError() {
	const toastElement = document.getElementById('copyErrorToast');
	if (toastElement) {
		const toast = new bootstrap.Toast(toastElement, {
			autohide: true,
			delay: 5000,
		});
		toast.show();
	}
}

function initializeClipboard() {
	try {
		if (typeof ClipboardJS === 'undefined') {
			console.error('ClipboardJS library not loaded');
			return;
		}

		if (window.currentClipboard) {
			window.currentClipboard.destroy();
		}

		window.currentClipboard = new ClipboardJS('.copy-btn', {
			text: function(trigger) {
				return getFormattedTableText();
			},
		});

		window.currentClipboard.on('success', function(e) {
			console.log('Copy successful');
			showCopySuccess();
			e.clearSelection();
		});

		window.currentClipboard.on('error', function(e) {
			console.warn('Copy failed');
			showCopyError();
			setTimeout(() => {
				showManualCopyModal(getFormattedTableText());
			}, 1000);
		});

	} catch (error) {
		console.error('Failed to initialize clipboard:', error);
		showCopyError();
		setupFallbackCopy();
	}
}

function showManualCopyModal(text) {
	const modalHtml = `
        <div class="modal fade" id="manualCopyModal" tabindex="-1" aria-labelledby="manualCopyModalLabel" aria-hidden="true">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="manualCopyModalLabel">
                            <i class="bi bi-clipboard me-2"></i>手動コピー
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>
                    <div class="modal-body">
                        <div class="alert alert-info" role="alert">
                            <i class="bi bi-info-circle me-2"></i>
                            自動コピーに失敗しました。以下の内容を手動で選択してコピーしてください。
                        </div>
                        <div class="form-floating">
                            <textarea class="form-control"
                                      placeholder="コピー用テキスト"
                                      id="copyTextArea"
                                      style="height: 200px"
                                      readonly>${text}</textarea>
                            <label for="copyTextArea">コピー用テキスト</label>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">
                            <i class="bi bi-x-lg me-1"></i>閉じる
                        </button>
                        <button type="button" class="btn btn-primary" onclick="selectAllText()">
                            <i class="bi bi-check2-square me-1"></i>全選択
                        </button>
                    </div>
                </div>
            </div>
        </div>
        `;

	const existingModal = document.getElementById('manualCopyModal');
	if (existingModal) {
		existingModal.remove();
	}

	document.body.insertAdjacentHTML('beforeend', modalHtml);
	const modal = new bootstrap.Modal(document.getElementById('manualCopyModal'));
	modal.show();

	modal._element.addEventListener('hidden.bs.modal', function() {
		modal._element.remove();
	});
}

function selectAllText() {
	const textArea = document.getElementById('copyTextArea');
	if (textArea) {
		textArea.select();
		textArea.setSelectionRange(0, 99999);

		try {
			document.execCommand('copy');
			showCopySuccess();
		} catch (err) {
			console.warn('Copy command failed:', err);
		}
	}
}

function getFormattedTableText() {
	const resultsDiv = document.getElementById('results');
	if (!resultsDiv) return '';

	const table = resultsDiv.querySelector('table');
	if (!table) return resultsDiv.innerText || '';

	let text = '';
	const rows = table.querySelectorAll('tr');

	rows.forEach(row => {
		const cells = row.querySelectorAll('th, td');
		const rowText = Array.from(cells).map(cell => cell.innerText.trim()).join('\t');
		text += rowText + '\n';
	});

	return text;
}

function setupFallbackCopy() {
	document.querySelectorAll('.copy-btn').forEach(btn => {
		btn.addEventListener('click', function(e) {
			e.preventDefault();
			const text = getFormattedTableText();

			if (navigator.clipboard && navigator.clipboard.writeText) {
				navigator.clipboard.writeText(text).then(() => showCopySuccess()).catch(() => {
					showCopyError();
					setTimeout(() => showManualCopyModal(text), 1000);
				});
			} else {
				showManualCopyModal(text);
			}
		});
	});
}

document.addEventListener('DOMContentLoaded', function() {
	if (document.getElementById('results').innerHTML.trim()) {
		initializeClipboard();
	}
});

// 全选列
function selectAllColumns() {
	const checkboxes = document.querySelectorAll('input[name="columns"]');
	checkboxes.forEach(checkbox => checkbox.checked = true);
}

// 全部取消选择
function deselectAllColumns() {
	const checkboxes = document.querySelectorAll('input[name="columns"]');
	checkboxes.forEach(checkbox => checkbox.checked = false);
}

// 获取选中的列
function getSelectedColumns() {
	const checkboxes = document.querySelectorAll('input[name="columns"]:checked');
	return Array.from(checkboxes).map(checkbox => checkbox.value);
}

// 验证是否至少选择了一列
function validateColumnSelection() {
	const selectedColumns = getSelectedColumns();
	if (selectedColumns.length === 0) {
		// 显示错误提示
		showColumnSelectionError();
		return false;
	}
	return true;
}

// 显示列选择错误提示
function showColumnSelectionError() {
	// 创建或显示错误 toast
	let errorToast = document.getElementById('columnSelectionErrorToast');

	if (!errorToast) {
		// 如果不存在，创建新的 toast
		const toastContainer = document.querySelector('.toast-container');
		const toastHtml = `
            <div id="columnSelectionErrorToast" class="toast" role="alert" aria-live="assertive" aria-atomic="true">
                <div class="toast-header">
                    <i class="bi bi-exclamation-triangle-fill text-warning me-2"></i>
                    <strong class="me-auto">选择提示</strong>
                    <small>たった今</small>
                    <button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="Close"></button>
                </div>
                <div class="toast-body">
                    表示する列を少なくとも1つ選択してください
                </div>
            </div>
        `;
		toastContainer.insertAdjacentHTML('beforeend', toastHtml);
		errorToast = document.getElementById('columnSelectionErrorToast');
	}

	const toast = new bootstrap.Toast(errorToast, {
		autohide: true,
		delay: 5000,
	});
	toast.show();
}

// 在 DOMContentLoaded 事件中添加表单提交验证
document.addEventListener('DOMContentLoaded', function() {
	// 添加表单提交验证
	const form = document.querySelector('form[hx-post="/analyze"]');
	if (form) {
		form.addEventListener('submit', function(e) {
			if (!validateColumnSelection()) {
				e.preventDefault();
				e.stopPropagation();
				return false;
			}
		});

		// 也要处理 HTMX 的提交事件
		form.addEventListener('htmx:configRequest', function(e) {
			if (!validateColumnSelection()) {
				e.preventDefault();
				return false;
			}
		});
	}
});

