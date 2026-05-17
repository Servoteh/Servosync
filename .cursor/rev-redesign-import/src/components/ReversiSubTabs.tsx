import React from 'react';
type SubTab = {
  key: string;
  label: string;
};
const SUB_TABS: SubTab[] = [
{
  key: 'katalog',
  label: 'Katalog'
},
{
  key: 'po-masinama',
  label: 'Po mašinama'
},
{
  key: 'po-zaposlenima',
  label: 'Po zaposlenima'
}];

type ReversiSubTabsProps = {
  active: string;
  onChange: (key: string) => void;
};
export function ReversiSubTabs({ active, onChange }: ReversiSubTabsProps) {
  return (
    <div className="flex items-center gap-1 border-b border-gray-200">
      {SUB_TABS.map((tab) => {
        const isActive = active === tab.key;
        return (
          <button
            key={tab.key}
            onClick={() => onChange(tab.key)}
            className={`px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${isActive ? 'border-primary text-primary' : 'border-transparent text-gray-500 hover:text-gray-800 hover:border-gray-300'}`}>
            
            {tab.label}
          </button>);

      })}
    </div>);

}