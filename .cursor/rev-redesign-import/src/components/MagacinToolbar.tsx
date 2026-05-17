import React from 'react';
import { Search, Download, Plus } from 'lucide-react';
type MagacinToolbarProps = {
  search: string;
  onSearch: (v: string) => void;
  group: 'sve' | 'rucni' | 'rezni';
  onGroupChange: (v: 'sve' | 'rucni' | 'rezni') => void;
  showZero: boolean;
  onShowZeroChange: (v: boolean) => void;
};
export function MagacinToolbar({
  search,
  onSearch,
  group,
  onGroupChange,
  showZero,
  onShowZeroChange
}: MagacinToolbarProps) {
  const groupBtn = (key: 'sve' | 'rucni' | 'rezni', label: string) =>
  <button
    onClick={() => onGroupChange(key)}
    className={`px-3 py-1.5 text-sm font-medium rounded-md transition-colors ${group === key ? 'bg-primary text-white shadow-sm' : 'text-gray-600 hover:bg-white hover:text-gray-900'}`}>
    
      {label}
    </button>;

  return (
    <div className="flex items-center gap-3 bg-gray-50 border border-gray-200 rounded-lg p-3 flex-wrap">
      <div className="relative flex-1 min-w-[260px]">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input
          type="text"
          value={search}
          onChange={(e) => onSearch(e.target.value)}
          placeholder="Pretraga po kataloškom broju, nazivu ili barkodu…"
          className="w-full pl-9 pr-3 py-2 text-sm bg-white border border-gray-200 rounded-md focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary" />
        
      </div>

      <div className="flex items-center gap-2">
        <span className="text-xs font-semibold tracking-wider text-gray-500 uppercase">
          Grupa
        </span>
        <div className="flex items-center gap-1 bg-gray-100 rounded-lg p-1">
          {groupBtn('sve', 'Sve')}
          {groupBtn('rucni', 'Ručni')}
          {groupBtn('rezni', 'Rezni')}
        </div>
      </div>

      <label className="flex items-center gap-2 text-sm font-medium text-gray-700 px-3 py-2 bg-white border border-gray-200 rounded-md cursor-pointer hover:border-gray-300">
        <input
          type="checkbox"
          checked={showZero}
          onChange={(e) => onShowZeroChange(e.target.checked)}
          className="w-4 h-4 accent-primary" />
        
        Prikaži i nulta stanja
      </label>

      <div className="flex items-center gap-2 ml-auto">
        <button className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-green-700 bg-green-50 border border-green-200 rounded-md hover:bg-green-100 transition-colors">
          <Download className="w-4 h-4" />
          Excel
        </button>
        <button className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-white bg-primary rounded-md hover:bg-primary-hover transition-colors shadow-sm">
          <Plus className="w-4 h-4" />
          Novi artikal
        </button>
      </div>
    </div>);

}