import { describe, it, expect, beforeEach } from 'vitest';
import {
  getLokacijeUiState,
  setLokacijeActiveTab,
  setBrowseFilter,
  setItemsFilter,
  setItemsPage,
  setItemsPageSize,
} from '../../src/state/lokacije.js';

/* storage.js je fail-safe (try/catch na localStorage), pa testovi rade
 * u Node-u (bez jsdom-a) — lsSetJSON-i samo catch-uju grešku. */

describe('state/lokacije — normalizeTab', () => {
  beforeEach(() => {
    setLokacijeActiveTab('dashboard');
  });

  it('postavlja validan tab', () => {
    setLokacijeActiveTab('items');
    expect(getLokacijeUiState().activeTab).toBe('items');
  });

  it('odbija nevalidan tab i fallback-uje na dashboard', () => {
    setLokacijeActiveTab('zlonamerno');
    expect(getLokacijeUiState().activeTab).toBe('dashboard');
  });

  it('odbija ne-string vrednosti', () => {
    setLokacijeActiveTab(null);
    expect(getLokacijeUiState().activeTab).toBe('dashboard');
    setLokacijeActiveTab(42);
    expect(getLokacijeUiState().activeTab).toBe('dashboard');
  });
});

describe('state/lokacije — filter normalizacija', () => {
  it('browseFilter strip-uje kontrol znakove i trim-uje dužinu', () => {
    setBrowseFilter('abc\x00def');
    expect(getLokacijeUiState().browseFilter).toBe('abcdef');
  });

  it('browseFilter ograničava na 120 znakova', () => {
    setBrowseFilter('x'.repeat(200));
    expect(getLokacijeUiState().browseFilter).toHaveLength(120);
  });

  it('itemsFilter resetuje paginaciju na 0', () => {
    setItemsPage(3);
    setItemsFilter('xyz');
    expect(getLokacijeUiState().itemsPage).toBe(0);
  });

  it('non-string filter → ""', () => {
    setBrowseFilter(null);
    expect(getLokacijeUiState().browseFilter).toBe('');
    setBrowseFilter(undefined);
    expect(getLokacijeUiState().browseFilter).toBe('');
  });
});

describe('state/lokacije — paginacija', () => {
  it('setItemsPage ne prihvata negativne vrednosti', () => {
    setItemsPage(-5);
    expect(getLokacijeUiState().itemsPage).toBe(0);
  });

  it('setItemsPageSize fallback na 50 za nevalidne vrednosti', () => {
    setItemsPageSize(7);
    expect(getLokacijeUiState().itemsPageSize).toBe(50);
    setItemsPageSize('abc');
    expect(getLokacijeUiState().itemsPageSize).toBe(50);
  });

  it('setItemsPageSize prihvata whitelist vrednosti', () => {
    for (const n of [25, 50, 100, 250]) {
      setItemsPageSize(n);
      expect(getLokacijeUiState().itemsPageSize).toBe(n);
    }
  });

  it('setItemsPageSize resetuje page na 0', () => {
    setItemsPage(5);
    setItemsPageSize(100);
    expect(getLokacijeUiState().itemsPage).toBe(0);
  });
});
