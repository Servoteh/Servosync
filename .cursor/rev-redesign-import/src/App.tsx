import React, { useState } from 'react';
import { RotateCcw, Scissors } from 'lucide-react';
import { TopNav } from './components/TopNav';
import { ReversiTabs } from './components/ReversiTabs';
import { ReversiSubTabs } from './components/ReversiSubTabs';
import { PageHeader } from './components/PageHeader';
import { RezniAlatStats } from './components/RezniAlatStats';
import { RezniAlatToolbar } from './components/RezniAlatToolbar';
import { RezniAlatTable } from './components/RezniAlatTable';
export function App() {
  const [activeTab, setActiveTab] = useState('rezni');
  const [activeSub, setActiveSub] = useState('katalog');
  const [search, setSearch] = useState('');
  const [klasa, setKlasa] = useState('all');
  const [masina, setMasina] = useState('all');
  const [status, setStatus] = useState('aktivne');
  const [selected, setSelected] = useState<string[]>([]);
  return (
    <div className="min-h-screen bg-background flex flex-col font-sans">
      <header className="sticky top-0 z-20 bg-white">
        <TopNav title="Reversi" subtitle="Alati i oprema" icon={RotateCcw} />
        <ReversiTabs active={activeTab} onChange={setActiveTab} />
      </header>

      <main className="flex-1 px-6 py-5 space-y-4">
        {activeTab === 'rezni' ?
        <>
            <PageHeader
            icon={Scissors}
            title="Rezni alat"
            subtitle="Katalog šifri — jedna šifra → količina po lokaciji. Stanje na mašinama se gomila iz svih aktivnih reversa za tu šifru." />
          

            <ReversiSubTabs active={activeSub} onChange={setActiveSub} />

            {activeSub === 'katalog' ?
          <>
                <RezniAlatStats />
                <RezniAlatToolbar
              search={search}
              onSearch={setSearch}
              klasa={klasa}
              onKlasaChange={setKlasa}
              masina={masina}
              onMasinaChange={setMasina}
              status={status}
              onStatusChange={setStatus}
              selectedCount={selected.length} />
            
                <RezniAlatTable
              search={search}
              klasa={klasa}
              masina={masina}
              status={status}
              selected={selected}
              onSelectedChange={setSelected} />
            
              </> :

          <div className="bg-white border border-gray-200 rounded-lg shadow-sm p-12 text-center">
                <p className="text-gray-500">
                  Sub-tab "
                  <span className="font-semibold text-gray-700">
                    {activeSub}
                  </span>
                  " — prototip prikazuje samo "Katalog" sa kompletnim sadržajem.
                </p>
              </div>
          }
          </> :

        <div className="bg-white border border-gray-200 rounded-lg shadow-sm p-12 text-center">
            <p className="text-gray-500">
              Tab "
              <span className="font-semibold text-gray-700">{activeTab}</span>"
              — prototip prikazuje samo "Rezni alat" sa kompletnim sadržajem.
            </p>
          </div>
        }
      </main>
    </div>);

}