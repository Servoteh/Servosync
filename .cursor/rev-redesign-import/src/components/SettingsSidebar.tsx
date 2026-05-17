import React, { Component } from 'react';
import {
  Users,
  Building2,
  UserCog,
  Layers,
  Database,
  ShieldCheck,
  Bell,
  Plug,
  History,
  FileBox,
  Cog } from
'lucide-react';
export interface SettingsItem {
  id: string;
  label: string;
  icon: ComponentType<{
    className?: string;
  }>;
  badge?: number | string;
  badgeTone?: 'default' | 'primary';
}
export interface SettingsGroup {
  label: string;
  items: SettingsItem[];
}
export const SETTINGS_NAV: SettingsGroup[] = [
{
  label: 'Korisnici i pristup',
  items: [
  {
    id: 'korisnici',
    label: 'Korisnici',
    icon: Users,
    badge: 12,
    badgeTone: 'primary'
  },
  {
    id: 'uloge',
    label: 'Uloge i dozvole',
    icon: ShieldCheck,
    badge: 6
  },
  {
    id: 'timovi',
    label: 'Timovi',
    icon: UserCog,
    badge: 4
  }]

},
{
  label: 'Organizacija',
  items: [
  {
    id: 'organizacija',
    label: 'Organizacija',
    icon: Building2
  },
  {
    id: 'odeljenja',
    label: 'Odeljenja',
    icon: Layers,
    badge: 6
  }]

},
{
  label: 'Podaci',
  items: [
  {
    id: 'maticni',
    label: 'Matični podaci',
    icon: Database
  },
  {
    id: 'odrz-profili',
    label: 'Održ. profili',
    icon: FileBox
  },
  {
    id: 'podesavanje',
    label: 'Podeš. predmeta',
    icon: Cog
  }]

},
{
  label: 'Sistem',
  items: [
  {
    id: 'integracije',
    label: 'Integracije',
    icon: Plug,
    badge: 'NEW',
    badgeTone: 'primary'
  },
  {
    id: 'notifikacije',
    label: 'Notifikacije',
    icon: Bell
  },
  {
    id: 'audit',
    label: 'Audit log',
    icon: History
  }]

}];

interface Props {
  active: string;
  onChange: (id: string) => void;
}
export function SettingsSidebar({ active, onChange }: Props) {
  return (
    <aside className="w-64 shrink-0 bg-white border-r border-gray-200 overflow-y-auto">
      <div className="px-4 py-4 border-b border-gray-100">
        <span className="text-[10px] font-bold text-gray-500 tracking-wider">
          PODEŠAVANJA
        </span>
        <h2 className="text-sm font-semibold text-gray-900 mt-0.5">
          Sistem konfiguracija
        </h2>
      </div>

      <nav className="p-3 space-y-5">
        {SETTINGS_NAV.map((group) =>
        <div key={group.label}>
            <div className="px-2 mb-1.5 text-[10px] font-bold text-gray-400 tracking-wider uppercase">
              {group.label}
            </div>
            <ul className="space-y-0.5">
              {group.items.map((item) => {
              const Icon = item.icon;
              const isActive = active === item.id;
              return (
                <li key={item.id}>
                    <button
                    onClick={() => onChange(item.id)}
                    className={`w-full flex items-center gap-2.5 px-2.5 py-2 text-sm rounded-md transition-colors ${isActive ? 'bg-primary-light text-primary font-semibold' : 'text-gray-700 hover:bg-gray-100'}`}>
                    
                      <Icon
                      className={`w-4 h-4 ${isActive ? 'text-primary' : 'text-gray-400'}`} />
                    
                      <span className="flex-1 text-left">{item.label}</span>
                      {item.badge !== undefined &&
                    <span
                      className={`px-1.5 py-0.5 text-[10px] font-bold rounded-full ${item.badgeTone === 'primary' ? 'bg-primary text-white' : isActive ? 'bg-primary-light text-primary border border-primary/20' : 'bg-gray-100 text-gray-500'}`}>
                      
                          {item.badge}
                        </span>
                    }
                    </button>
                  </li>);

            })}
            </ul>
          </div>
        )}
      </nav>

      <div className="px-4 py-3 border-t border-gray-100 text-[11px] text-gray-500">
        v 2.4.1 · build 2026.05
      </div>
    </aside>);

}