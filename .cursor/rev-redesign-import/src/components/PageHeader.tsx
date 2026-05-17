import React, { Component } from 'react';
interface Props {
  title: string;
  subtitle?: string;
  icon: ComponentType<{
    className?: string;
  }>;
  actions?: React.ReactNode;
}
export function PageHeader({ title, subtitle, icon: Icon, actions }: Props) {
  return (
    <div className="flex items-start justify-between gap-4 pb-4 border-b border-gray-200">
      <div className="flex items-center gap-3 min-w-0">
        <div className="flex items-center justify-center w-10 h-10 bg-primary-light rounded-lg text-primary shrink-0">
          <Icon className="w-5 h-5" />
        </div>
        <div className="min-w-0">
          <h2 className="text-xl font-bold text-gray-900 leading-tight">
            {title}
          </h2>
          {subtitle &&
          <p className="text-sm text-gray-500 mt-0.5">{subtitle}</p>
          }
        </div>
      </div>
      {actions &&
      <div className="flex items-center gap-2 shrink-0">{actions}</div>
      }
    </div>);

}