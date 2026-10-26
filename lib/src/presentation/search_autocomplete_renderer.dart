import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../infrastructure/blogger_data_service.dart';
import 'ui_manager.dart';

class SearchAutocompleteRenderer {
  final String inputId;
  final BloggerDataService bloggerService;

  web.HTMLDivElement? _dropdown;
  int _selectedIndex = -1;
  List<String> _suggestions = [];
  Timer? _debounceTimer;

  SearchAutocompleteRenderer(this.inputId, this.bloggerService) {
    _init();
  }

  void _init() {
    final input = UIManager.el(inputId) as web.HTMLInputElement?;
    if (input == null) return;

    input.setAttribute('autocomplete', 'off');

    _dropdown = web.document.createElement('div') as web.HTMLDivElement;
    _dropdown!.className = 'antinna-search-dropdown';

    final group = input.closest('.search-input-group') ?? input.parentElement;
    if (group != null) {
      (group as web.HTMLElement).style.setProperty('position', 'relative', 'important');
      group.appendChild(_dropdown!);
    }

    input.oninput = ((web.Event e) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _handleInput(input.value);
      });
    }).toJS;

    input.onkeydown = ((web.KeyboardEvent e) {
      _handleKeydown(e);
    }).toJS;

    web.document.addEventListener('click', ((web.MouseEvent e) {
      final target = e.target as web.Node?;
      if (target != null && !input.contains(target) && !(_dropdown?.contains(target) ?? false)) {
        _hide();
      }
    }).toJS);
  }

  Future<void> _handleInput(String value) async {
    if (value.length < 2) {
      _hide();
      return;
    }

    _suggestions = await bloggerService.fetchSearchSuggestions(value);
    _render();
  }

  void _render() {
    if (_dropdown == null) return;

    if (_suggestions.isEmpty) {
      _hide();
      return;
    }

    _dropdown!.innerHTML = _suggestions.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      final activeClass = i == _selectedIndex ? 'active' : '';
      return '''
        <div class="antinna-search-item $activeClass" data-val="${s.replaceAll('"', '&quot;')}">
            $s
        </div>
      ''';
    }).join('');

    final items = _dropdown!.querySelectorAll('.antinna-search-item');
    for (int i = 0; i < items.length; i++) {
      final item = items.item(i) as web.HTMLElement?;
      if (item != null) {
        item.onclick = ((web.MouseEvent e) {
          final val = item.getAttribute('data-val') ?? '';
          _select(val);
        }).toJS;
      }
    }

    _dropdown!.style.display = 'block';
  }

  void _handleKeydown(web.KeyboardEvent e) {
    if (_dropdown?.style.display != 'block') return;

    if (e.key == 'ArrowDown') {
      e.preventDefault();
      _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
      _render();
    } else if (e.key == 'ArrowUp') {
      e.preventDefault();
      _selectedIndex = (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
      _render();
    } else if (e.key == 'Enter' && _selectedIndex >= 0) {
      e.preventDefault();
      _select(_suggestions[_selectedIndex]);
    } else if (e.key == 'Escape') {
      _hide();
    }
  }

  void _select(String val) {
    final input = UIManager.el(inputId) as web.HTMLInputElement?;
    if (input != null) {
      input.value = val;
      _hide();
      input.form?.dispatchEvent(web.Event('submit', web.EventInit(cancelable: true, bubbles: true)));
    }
  }

  void _hide() {
    if (_dropdown != null) {
      _dropdown!.style.display = 'none';
      _selectedIndex = -1;
    }
  }
}
