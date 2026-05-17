import React from 'react';
import { ArrowLeft, LogOut, Moon, BoxIcon } from 'lucide-react';
type TopNavProps = {
  title: string;
  subtitle?: string;
  icon: BoxIcon;
};
export function TopNav({ title, subtitle, icon: Icon }: TopNavProps) {
  return (
    <div className="flex items-center justify-between px-6 py-3 bg-white border-b border-gray-200">
      <div className="flex items-center gap-4">
        <button className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-gray-600 hover:bg-gray-100 rounded-md transition-colors border border-gray-200">
          <ArrowLeft className="w-4 h-4" />
          Moduli
        </button>
        <div className="flex items-center gap-3 ml-2">
          <div className="flex items-center justify-center w-8 h-8 bg-primary rounded-md text-white shadow-sm">
            <Icon className="w-5 h-5" />
          </div>
          <div className="flex items-baseline gap-2">
            <h1 className="text-xl font-bold text-gray-900 tracking-tight">
              {title}
            </h1>
            {subtitle &&
            <span className="text-sm text-gray-500">{subtitle}</span>
            }
          </div>
        </div>
      </div>

      <div className="flex items-center gap-4">
        <button className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-full transition-colors">
          <Moon className="w-5 h-5" />
        </button>
        <div className="flex items-center gap-3 pl-4 border-l border-gray-200">
          <span className="px-2.5 py-1 text-xs font-bold text-primary bg-primary-light rounded-md">
            ADMIN
          </span>
          <button className="flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-gray-900 transition-colors">
            Odjavi se
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>);

}