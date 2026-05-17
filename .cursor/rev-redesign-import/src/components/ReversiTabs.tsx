import React from 'react';
import {
  User,
  Package,
  ClipboardList,
  Boxes,
  Scissors,
  BoxIcon } from
'lucide-react';
type Tab = {
  key: string;
  label: string;
  icon: BoxIcon;
  count?: number;
};
const TABS: Tab[] = [
{
  key: 'moja',
  label: 'Moja zaduženja',
  icon: User,
  count: 0
},
{
  key: 'magacin',
  label: 'Magacin',
  icon: Package,
  count: 247
},
{
  key: 'zaduzenja',
  label: 'Zaduženja',
  icon: ClipboardList,
  count: 0
},
{
  key: 'inventar',
  label: 'Inventar alata i opreme',
  icon: Boxes,
  count: 0
},
{
  key: 'rezni',
  label: 'Rezni alat',
  icon: Scissors,
  count: 0
}];

type ReversiTabsProps = {
  active: string;
  onChange: (key: string) => void;
};
export function ReversiTabs({ active, onChange }: ReversiTabsProps) {
  return (
    <div className="bg-white border-b border-gray-200 px-6">
      <nav
        className="flex items-center gap-1 overflow-x-auto"
        aria-label="Reversi sekcije">
        
        {TABS.map((tab) => {
          const isActive = active === tab.key;
          const Icon = tab.icon;
          return (
            <button
              key={tab.key}
              onClick={() => onChange(tab.key)}
              className={`flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap ${isActive ? 'border-primary text-primary' : 'border-transparent text-gray-600 hover:text-gray-900 hover:border-gray-300'}`}>
              
              <Icon className="w-4 h-4" />
              {tab.label}
              {typeof tab.count === 'number' &&
              <span
                className={`ml-1 px-1.5 py-0.5 rounded text-xs font-semibold ${isActive ? 'bg-primary-light text-primary' : 'bg-gray-100 text-gray-500'}`}>
                
                  {tab.count}
                </span>
              }
            </button>);

        })}
      </nav>
    </div>);

}