import { BloggerDataService } from '../infrastructure/BloggerDataService';
import { UIManager } from './UIManager';

export class SearchAutocompleteRenderer {
  private dropdown: HTMLElement | null = null;
  private selectedIndex: number = -1;
  private suggestions: string[] = [];

  constructor(
    private inputId: string,
    private bloggerService: BloggerDataService
  ) {
    this.init();
  }

  private init(): void {
    const input = UIManager.el<HTMLInputElement>(this.inputId);
    if (!input) return;

    input.setAttribute('autocomplete', 'off');

    // Create dropdown
    this.dropdown = document.createElement('div');
    this.dropdown.className = 'antinna-search-dropdown';

    // Find a suitable parent that spans the search bar
    const group = input.closest('.search-input-group') || input.parentElement;
    if (group) {
        group.style.setProperty('position', 'relative', 'important');
        group.appendChild(this.dropdown);
    }

    let debounceTimer: any;
    input.oninput = () => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => this.handleInput(input.value), 300);
    };

    input.onkeydown = (e) => this.handleKeydown(e);

    document.addEventListener('click', (e) => {
        if (!input.contains(e.target as Node) && !this.dropdown?.contains(e.target as Node)) {
            this.hide();
        }
    });
  }

  private async handleInput(value: string): Promise<void> {
    if (value.length < 2) {
        this.hide();
        return;
    }

    this.suggestions = await this.bloggerService.fetchSearchSuggestions(value);
    this.render();
  }

  private render(): void {
    if (!this.dropdown) return;

    if (this.suggestions.length === 0) {
        this.hide();
        return;
    }

    this.dropdown.innerHTML = this.suggestions.map((s, i) => `
        <div class="antinna-search-item ${i === this.selectedIndex ? 'active' : ''}"
             onclick="window.handleSuggestionClick('${s.replace(/'/g, "\\'")}')">
            ${s}
        </div>
    `).join('');

    (window as any).handleSuggestionClick = (val: string) => this.select(val);

    this.dropdown.style.display = 'block';
  }

  private handleKeydown(e: KeyboardEvent): void {
    if (this.dropdown?.style.display !== 'block') return;

    if (e.key === 'ArrowDown') {
        e.preventDefault();
        this.selectedIndex = (this.selectedIndex + 1) % this.suggestions.length;
        this.render();
    } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        this.selectedIndex = (this.selectedIndex - 1 + this.suggestions.length) % this.suggestions.length;
        this.render();
    } else if (e.key === 'Enter' && this.selectedIndex >= 0) {
        e.preventDefault();
        this.select(this.suggestions[this.selectedIndex]);
    } else if (e.key === 'Escape') {
        this.hide();
    }
  }

  private select(val: string): void {
    const input = UIManager.el<HTMLInputElement>(this.inputId);
    if (input) {
        input.value = val;
        this.hide();
        input.form?.dispatchEvent(new Event('submit', { cancelable: true, bubbles: true }));
    }
  }

  private hide(): void {
    if (this.dropdown) {
        this.dropdown.style.display = 'none';
        this.selectedIndex = -1;
    }
  }
}
