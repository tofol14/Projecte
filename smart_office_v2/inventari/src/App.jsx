import React, { useEffect, useMemo, useState } from 'react'

const SAMPLE = [
    { 
        id: 1, 
        codi: 'MT-001', 
        nom: 'Escales', 
        categoria: 'Eines', 
        ubicacio: 'Magatzem planta baixa (45m²) - Zona eines grans', 
        quantitat: 4, 
        estat: 'Bon estat', 
        dataRevisio: '2025-09-15', 
        observacions: 'Inventari general d\'escales. Espai dedicat: 8m²', 
        eines: [
            { nom: 'Escala telescòpica 3.8m HAILO ProfiLot', disponible: 1 },
            { nom: 'Escala simple 2m MARCA-X', disponible: 2 },
            { nom: 'Escala doble 1.5m alumini ZARGES', disponible: 1 }
        ] 
    },
    { 
        id: 2, 
        codi: 'MT-002', 
        nom: 'Caixa eines completa', 
        categoria: 'Eines', 
        ubicacio: 'Magatzem planta baixa', 
        quantitat: 3, 
        estat: 'Necessita revisió', 
        dataRevisio: '2025-08-20', 
        observacions: 'Falten claus Allen', 
        eines: [ 
            { nom: 'Martell', disponible: 3 } 
        ] 
    },
]

const CATEGORIES = ['Tots', 'Eines', 'Electricitat', 'Lampisteria', 'Pintura', 'Jardineria', 'Neteja', 'Seguretat', 'HVAC', 'Altres']
const MOTIUS = ['Reposició', "Ús de manteniment", 'Correcció', 'Altres']
const ESTATS = ['Tots', 'Bon estat', 'Necessita revisió', 'Necessita reparació', 'Fora de servei']

function useLocalStorage(key, initial) {
    const [state, setState] = useState(() => {
        try { 
            const raw = localStorage.getItem(key)
            return raw ? JSON.parse(raw) : initial 
        } catch(e) { 
            return initial 
        }
    })

    useEffect(() => { 
        try { 
            localStorage.setItem(key, JSON.stringify(state)) 
        } catch(e){} 
    }, [key, state])

    return [state, setState]
}

// Component principal
export default function App() {
    const [items, setItems] = useLocalStorage('inventari_items_v5', SAMPLE)
    const [moviments, setMoviments] = useLocalStorage('inventari_moviments_v5', [])
    const [query, setQuery] = useState('')
    const [categoryFilter, setCategoryFilter] = useState('Tots')
    const [statusFilter, setStatusFilter] = useState('Tots')
    const [showForm, setShowForm] = useState(false)
    const [movementModal, setMovementModal] = useState({ 
        open: false, 
        itemId: null, 
        delta: 0, 
        type: 'Entrada', 
        motiu: MOTIUS[0], 
        user: 'Administrador' 
    })
    const [historyModal, setHistoryModal] = useState({ 
        open: false, 
        itemId: null 
    })
    const [form, setForm] = useState({ 
        codi: '', 
        nom: '', 
        categoria: 'Eines', 
        ubicacio: '', 
        quantitat: 1, 
        estat: 'Bon estat', 
        dataRevisio: '', 
        observacions: '' 
    })

    // Funcions d'utilitat
    function isValidDate(dateString) {
        const today = new Date()
        const date = new Date(dateString)
        return date >= today
    }

    function needsRevisionSoon(item) {
        if (!item.dataRevisio) return false
        const revisionDate = new Date(item.dataRevisio)
        const today = new Date()
        const diffTime = revisionDate.getTime() - today.getTime()
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
        return diffDays <= 30
    }

    function getStorageUsage() {
        let total = 0;
        for (let key in localStorage) {
            if (localStorage.hasOwnProperty(key)) {
                total += localStorage[key].length * 2; // Aproximat en bytes
            }
        }
        return {
            used: total,
            usedMB: (total / (1024 * 1024)).toFixed(2),
            percentage: ((total / (5 * 1024 * 1024)) * 100).toFixed(1) // Assumim 5MB mínim
        };
    }

    function exportToJSON(items, moviments) {
        // Crear l'objecte amb les dades
        const data = {
            items,
            moviments,
            exportDate: new Date().toISOString(),
            version: "v5",
            location: "Edifici Misericòrdia"
        }
        
        // Formatejar la data pel nom de l'arxiu
        const date = new Date()
        const dateStr = date.toISOString().split('T')[0]
        const timeStr = date.toLocaleTimeString().replace(/:/g, '-')
        const fileName = `edifici_misericordia_inventari_${dateStr}_${timeStr}.json`
        
        // Crear i descarregar l'arxiu
        const blob = new Blob([JSON.stringify(data, null, 2)], { 
            type: 'application/json;charset=utf-8' 
        })
        const url = URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = fileName
        
        // Mostrar missatge a l'usuari
        const msg = `S'exportarà l'arxiu '${fileName}' a la carpeta de descàrregues`
        alert(msg)
        
        // Executar la descàrrega
        document.body.appendChild(a)
        a.click()
        document.body.removeChild(a)
        URL.revokeObjectURL(url)
    }

    // Filtratge d'items
    const filtered = useMemo(() => items.filter(it => {
        const q = query.trim().toLowerCase()
        if (q) {
            if (!(it.nom.toLowerCase().includes(q) || 
                it.codi.toLowerCase().includes(q) || 
                it.ubicacio.toLowerCase().includes(q))) 
                return false
        }
        if (categoryFilter !== 'Tots' && it.categoria !== categoryFilter) return false
        if (statusFilter !== 'Tots' && it.estat !== statusFilter) return false
        return true
    }), [items, query, categoryFilter, statusFilter])

    // Funcions principals
    function addItem() {
        if (!form.codi || !form.nom) {
            alert('Omple almenys codi i nom')
            return
        }
        if (form.dataRevisio && !isValidDate(form.dataRevisio)) {
            alert('La data de revisió no pot ser anterior a avui')
            return
        }
        const newIt = { 
            ...form, 
            id: Date.now(), 
            quantitat: Math.max(0, parseInt(form.quantitat) || 0), 
            eines: form.categoria === 'Eines' ? [] : undefined 
        }
        setItems(prev => [...prev, newIt])
        addMovement(newIt.id, 'Creació', 0, 'Creació d\'article', 'Administrador')
        setForm({ 
            codi: '', 
            nom: '', 
            categoria: 'Eines', 
            ubicacio: '', 
            quantitat: 1, 
            estat: 'Bon estat', 
            dataRevisio: '', 
            observacions: '' 
        })
        setShowForm(false)
    }

    function addMovement(itemId, tipus, quantitat, motiu, user) {
        const entry = { 
            id: Date.now(), 
            itemId, 
            tipus, 
            quantitat, 
            motiu, 
            user, 
            when: new Date().toISOString() 
        }
        setMoviments(prev => [...prev, entry])
    }

    function openMovementForChange(itemId, delta) {
        setMovementModal({ 
            open: true, 
            itemId, 
            delta: Math.abs(delta), 
            type: delta > 0 ? 'Entrada' : 'Sortida',
            motiu: MOTIUS[0], 
            user: 'Administrador' 
        })
    }

    function commitMovement() {
        const { itemId, delta, type, motiu, user } = movementModal
        setItems(prev => prev.map(it => {
            if (it.id !== itemId) return it
            const newQty = Math.max(0, it.quantitat + (type === 'Entrada' ? delta : -delta))
            return { ...it, quantitat: newQty }
        }))
        addMovement(itemId, type, (type === 'Entrada' ? delta : -delta), motiu, user)
        setMovementModal({ 
            open: false, 
            itemId: null, 
            delta: 0, 
            type: 'Entrada', 
            motiu: MOTIUS[0], 
            user: 'Administrador' 
        })
    }

    function changeQtyDirect(itemId, newQty) {
        const old = items.find(i => i.id === itemId)?.quantitat || 0
        const delta = newQty - old
        if (delta === 0) return
        openMovementForChange(itemId, delta)
    }

    function deleteItem(id) {
        if (!confirm('Eliminar article?')) return
        setItems(prev => prev.filter(i => i.id !== id))
        setMoviments(prev => prev.filter(m => m.itemId !== id))
    }

    function getMovimentsFor(itemId) {
        return moviments
            .filter(m => m.itemId === itemId)
            .sort((a,b) => new Date(b.when) - new Date(a.when))
    }

    // Render
    return (
        <div className="app-container">
            <header className="header-container">
                <div className="flex items-start justify-between gap-8">
                    <div className="flex-1">
                        <div className="flex items-center justify-between">
                            <div>
                                <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-500 to-cyan-500">
                                    Inventari de Manteniment
                                </h1>
                                <h2 className="text-xl mt-2 text-blue-200">
                                    Edifici Misericòrdia
                                </h2>
                                <div className="mt-2 text-sm text-gray-400">
                                    Magatzem planta baixa: 45m² | Oficina manteniment segona planta: 30m²
                                </div>
                                <div className="mt-1 text-xs text-gray-500">
                                    {(() => {
                                        const usage = getStorageUsage();
                                        return `Ús emmagatzematge: ${usage.usedMB}MB (${usage.percentage}% utilitzat)`
                                    })()}
                                </div>
                            </div>
                            <div className="flex items-center gap-6">
                                <div className="flex gap-2">
                                    <div className="relative group">
                                        <button 
                                            onClick={() => exportToJSON(items, moviments)}
                                            className="px-3 py-1.5 bg-gray-700 hover:bg-gray-600 text-white text-sm rounded-md flex items-center gap-2 transition-colors"
                                        >
                                            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                                                <path fillRule="evenodd" d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z" clipRule="evenodd" />
                                            </svg>
                                            Exportar JSON
                                        </button>
                                        <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-2 bg-gray-900 text-white text-xs rounded-lg opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
                                            Exporta les dades per usar-les a un altre ordinador
                                        </div>
                                    </div>
                                    <div className="relative group">
                                        <button
                                            onClick={() => {
                                                const input = document.createElement('input')
                                                input.type = 'file'
                                                input.accept = '.json'
                                                input.onchange = (e) => {
                                                    const file = e.target.files[0]
                                                    if (file) {
                                                        const reader = new FileReader()
                                                        reader.onload = (e) => {
                                                            try {
                                                                const data = JSON.parse(e.target.result)
                                                                if (data.items && data.moviments) {
                                                                    if (confirm('Això reemplaçarà totes les dades actuals. Continuar?')) {
                                                                        setItems(data.items)
                                                                        setMoviments(data.moviments)
                                                                        alert('Dades importades correctament!')
                                                                    }
                                                                } else {
                                                                    alert('Format d\'arxiu incorrecte')
                                                                }
                                                            } catch (err) {
                                                                alert('Error al llegir l\'arxiu')
                                                            }
                                                        }
                                                        reader.readAsText(file)
                                                    }
                                                }
                                                input.click()
                                            }}
                                            className="px-3 py-1.5 bg-gray-700 hover:bg-gray-600 text-white text-sm rounded-md flex items-center gap-2 transition-colors"
                                        >
                                            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                                                <path fillRule="evenodd" d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zM6.293 6.707a1 1 0 010-1.414l3-3a1 1 0 011.414 0l3 3a1 1 0 01-1.414 1.414L11 5.414V13a1 1 0 11-2 0V5.414L7.707 6.707a1 1 0 01-1.414 0z" />
                                            </svg>
                                            Importar JSON
                                        </button>
                                        <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-2 bg-gray-900 text-white text-xs rounded-lg opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
                                            Importa dades des d'un altre ordinador
                                        </div>
                                    </div>
                                    <div className="relative group">
                                        <button 
                                            onClick={() => {
                                                window.open('https://github.com/tofol14/Projecte/tree/main/smart_office_v2/inventari', '_blank')
                                            }}
                                            className="px-3 py-1.5 bg-gray-700 hover:bg-gray-600 text-white text-sm rounded-md flex items-center gap-2 transition-colors"
                                        >
                                            <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                                                <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                                            </svg>
                                            Codi Font
                                        </button>
                                        <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-2 bg-gray-900 text-white text-xs rounded-lg opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
                                            Accedeix al codi a GitHub
                                        </div>
                                    </div>
                                </div>
                                <img 
                                    src="/images/logo-consell.png" 
                                    alt="Consell de Mallorca" 
                                    className="h-28 object-contain"
                                    style={{
                                        maxWidth: '320px'
                                    }}
                                />
                            </div>
                        </div>
                        <div className="mt-6">
                            <img 
                                src="./images/misericordia.jpg" 
                                alt="Edifici Misericòrdia" 
                                className="rounded-lg shadow-lg w-full object-cover bg-gray-900 border border-gray-700"
                                style={{ height: "240px", maxWidth: "100%" }}
                                onError={(e) => {
                                    console.error('Error loading image:', e);
                                    e.target.onerror = null;
                                    e.target.style.display = 'none';
                                }}
                            />
                        </div>
                    </div>
                </div>
            </header>

            <main className="content-container grid grid-cols-1 lg:grid-cols-4 gap-6">
                {/* Sidebar amb filtres i formulari */}
                <aside className="lg:col-span-1">
                    <div className="card p-4 space-y-6">
                        <div>
                            <label className="block text-sm font-medium mb-2">Cerca</label>
                            <div className="relative">
                                <input 
                                    value={query} 
                                    onChange={e => setQuery(e.target.value)} 
                                    placeholder="Cerca per nom, codi, ubicació..." 
                                    className="w-full pl-10 pr-4 py-2" 
                                />
                                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 absolute left-3 top-2.5 text-gray-400" viewBox="0 0 20 20" fill="currentColor">
                                    <path fillRule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clipRule="evenodd" />
                                </svg>
                            </div>
                        </div>

                        <div className="grid grid-cols-2 gap-4 mt-6">
                            <div>
                                <label className="block text-sm font-medium mb-2">Categoria</label>
                                <select 
                                    value={categoryFilter} 
                                    onChange={e => setCategoryFilter(e.target.value)}
                                >
                                    {CATEGORIES.map(c => (
                                        <option key={c} value={c}>{c}</option>
                                    ))}
                                </select>
                            </div>
                            <div>
                                <label className="block text-sm font-medium mb-2">Estat</label>
                                <select 
                                    value={statusFilter} 
                                    onChange={e => setStatusFilter(e.target.value)}
                                >
                                    {ESTATS.map(s => (
                                        <option key={s} value={s}>{s}</option>
                                    ))}
                                </select>
                            </div>
                        </div>
                    </div>

                    {/* Formulari d'afegir article */}
                    <div className="card p-4 mt-6">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-lg font-medium">Afegir Article</h3>
                            <button 
                                onClick={() => setShowForm(s => !s)} 
                                className="btn btn-secondary text-sm"
                            >
                                {showForm ? 'Amagar' : 'Mostrar'}
                            </button>
                        </div>

                        {showForm && (
                            <div className="mt-3 space-y-2">
                                <input 
                                    placeholder="Codi" 
                                    value={form.codi} 
                                    onChange={e => setForm({...form, codi: e.target.value})} 
                                    className="w-full px-3 py-2 border rounded-lg bg-transparent" 
                                />
                                <input 
                                    placeholder="Nom" 
                                    value={form.nom} 
                                    onChange={e => setForm({...form, nom: e.target.value})} 
                                    className="w-full px-3 py-2 border rounded-lg bg-transparent" 
                                />
                                <select 
                                    value={form.categoria} 
                                    onChange={e => setForm({...form, categoria: e.target.value})} 
                                    className="w-full px-3 py-2 border rounded-lg bg-transparent"
                                >
                                    {CATEGORIES.filter(c => c !== 'Tots').map(c => (
                                        <option key={c} value={c}>{c}</option>
                                    ))}
                                </select>
                                <div className="grid grid-cols-2 gap-2">
                                    <input 
                                        type="number" 
                                        min="0" 
                                        value={form.quantitat} 
                                        onChange={e => setForm({...form, quantitat: e.target.value})} 
                                        className="px-3 py-2 border rounded-lg bg-transparent" 
                                    />
                                    <input 
                                        placeholder="Ubicació" 
                                        value={form.ubicacio} 
                                        onChange={e => setForm({...form, ubicacio: e.target.value})} 
                                        className="px-3 py-2 border rounded-lg bg-transparent" 
                                    />
                                </div>
                                <div className="grid grid-cols-2 gap-2">
                                    <select 
                                        value={form.estat} 
                                        onChange={e => setForm({...form, estat: e.target.value})} 
                                        className="px-3 py-2 border rounded-lg bg-transparent"
                                    >
                                        {ESTATS.filter(s => s !== 'Tots').map(s => (
                                            <option key={s} value={s}>{s}</option>
                                        ))}
                                    </select>
                                    <input 
                                        type="date" 
                                        value={form.dataRevisio} 
                                        onChange={e => setForm({...form, dataRevisio: e.target.value})} 
                                        className="px-3 py-2 border rounded-lg bg-transparent" 
                                    />
                                </div>
                                <textarea 
                                    placeholder="Observacions" 
                                    value={form.observacions} 
                                    onChange={e => setForm({...form, observacions: e.target.value})} 
                                    className="w-full px-3 py-2 border rounded-lg bg-transparent" 
                                    rows={2}
                                />
                                <div className="flex gap-2">
                                    <button 
                                        onClick={addItem} 
                                        className="flex-1 bg-indigo-600 text-white px-3 py-2 rounded-lg hover:bg-indigo-700 transition"
                                    >
                                        Crear
                                    </button>
                                    <button 
                                        onClick={() => setForm({ 
                                            codi: '', 
                                            nom: '', 
                                            categoria: 'Eines', 
                                            ubicacio: '', 
                                            quantitat: 1, 
                                            estat: 'Bon estat', 
                                            dataRevisio: '', 
                                            observacions: '' 
                                        })} 
                                        className="flex-1 border rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition"
                                    >
                                        Netejar
                                    </button>
                                </div>
                            </div>
                        )}
                    </div>
                </aside>

                {/* Taula principal */}
                <section className="lg:col-span-3">
                    <div className="table-container">
                        <div className="flex items-center justify-between p-4 border-b border-border">
                            <h2 className="text-lg font-medium">
                                Llista d'Articles
                                <span className="ml-2 text-sm text-gray-400">({filtered.length} articles)</span>
                            </h2>
                        </div>

                        <div className="overflow-x-auto">
                            <table>
                                <thead>
                                    <tr>
                                        <th>Codi</th>
                                        <th>Nom</th>
                                        <th>Categoria</th>
                                        <th>Ubicació</th>
                                        <th className="text-center">Quant.</th>
                                        <th>Estat</th>
                                        <th>Moviments</th>
                                        <th>Accions</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y">
                                    {filtered.map(it => (
                                        <tr 
                                            key={it.id} 
                                            className={`
                                                hover:bg-gray-50 dark:hover:bg-gray-700 transition
                                                ${needsRevisionSoon(it) ? 'bg-yellow-50 dark:bg-yellow-900/20' : ''}
                                            `}
                                        >
                                            <td className="px-3 py-3 align-top font-medium">{it.codi}</td>
                                            <td className="px-3 py-3 align-top">
                                                <div className="flex items-start gap-2">
                                                    <div>
                                                        {it.nom}
                                                        {it.observacions && (
                                                            <div className="text-xs text-gray-400 mt-1">
                                                                {it.observacions}
                                                            </div>
                                                        )}
                                                        {it.eines && (
                                                            <div className="mt-2">
                                                                <button 
                                                                    onClick={() => setHistoryModal({ 
                                                                        open: true, 
                                                                        itemId: it.id,
                                                                        isToolbox: true,
                                                                        tools: it.eines
                                                                    })}
                                                                    className="text-xs px-2 py-1 bg-gray-100 dark:bg-gray-700 rounded hover:bg-gray-200 dark:hover:bg-gray-600 transition"
                                                                >
                                                                    📦 {it.eines.length} eines
                                                                </button>
                                                            </div>
                                                        )}
                                                    </div>
                                                </div>
                                            </td>
                                            <td className="px-3 py-3 align-top">{it.categoria}</td>
                                            <td className="px-3 py-3 align-top">{it.ubicacio}</td>
                                            <td className="px-3 py-3 align-top text-center">
                                                <div className="inline-flex items-center gap-1">
                                                    <button 
                                                        onClick={() => openMovementForChange(it.id, -1)}
                                                        className="px-2 py-1 rounded border hover:bg-gray-50 dark:hover:bg-gray-700 transition"
                                                    >
                                                        -
                                                    </button>
                                                    <input 
                                                        type="number" 
                                                        value={it.quantitat} 
                                                        onChange={e => changeQtyDirect(it.id, Math.max(0, parseInt(e.target.value)||0))} 
                                                        className="w-14 text-center px-2 py-1 border rounded bg-transparent" 
                                                    />
                                                    <button 
                                                        onClick={() => openMovementForChange(it.id, +1)}
                                                        className="px-2 py-1 rounded border hover:bg-gray-50 dark:hover:bg-gray-700 transition"
                                                    >
                                                        +
                                                    </button>
                                                </div>
                                            </td>
                                            <td className="px-3 py-3 align-top">
                                                <select 
                                                    value={it.estat} 
                                                    onChange={e => setItems(prev => prev.map(x => 
                                                        x.id === it.id ? {...x, estat: e.target.value} : x
                                                    ))} 
                                                    className="px-2 py-1 border rounded bg-transparent"
                                                >
                                                    {ESTATS.filter(s => s !== 'Tots').map(s => (
                                                        <option key={s} value={s}>{s}</option>
                                                    ))}
                                                </select>
                                            </td>
                                            <td className="px-3 py-3 align-top">
                                                <button 
                                                    onClick={() => setHistoryModal({ open: true, itemId: it.id })} 
                                                    className="px-2 py-1 rounded border hover:bg-gray-50 dark:hover:bg-gray-700 transition"
                                                >
                                                    {getMovimentsFor(it.id).length} mov.
                                                </button>
                                            </td>
                                            <td className="px-3 py-3 align-top">
                                                <div className="flex gap-2">
                                                    <button 
                                                        onClick={() => {
                                                            const newObs = prompt('Observacions:', it.observacions||'')
                                                            if (newObs !== null) {
                                                                setItems(prev => prev.map(x => 
                                                                    x.id === it.id ? {...x, observacions: newObs} : x
                                                                ))
                                                            }
                                                        }} 
                                                        className="px-2 py-1 border rounded hover:bg-gray-50 dark:hover:bg-gray-700 transition"
                                                    >
                                                        Editar
                                                    </button>
                                                    <button 
                                                        onClick={() => deleteItem(it.id)} 
                                                        className="px-2 py-1 rounded border text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition"
                                                    >
                                                        Eliminar
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </section>
            </main>

            {/* Modal de moviments */}
            {movementModal.open && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
                    <div className="bg-white dark:bg-gray-800 rounded-lg p-4 w-full max-w-md">
                        <h3 className="font-semibold mb-2">
                            Registrar moviment — {movementModal.type}
                        </h3>
                        <div className="grid gap-2">
                            <label className="text-xs">Tipus</label>
                            <select 
                                value={movementModal.type} 
                                onChange={e => setMovementModal(m => ({...m, type: e.target.value}))} 
                                className="px-3 py-2 border rounded bg-transparent"
                            >
                                <option>Entrada</option>
                                <option>Sortida</option>
                            </select>

                            <label className="text-xs">Quantitat</label>
                            <input 
                                type="number" 
                                min="0" 
                                value={movementModal.delta} 
                                onChange={e => setMovementModal(m => ({
                                    ...m, 
                                    delta: Math.max(0, parseInt(e.target.value)||0)
                                }))} 
                                className="px-3 py-2 border rounded bg-transparent" 
                            />

                            <label className="text-xs">Motiu</label>
                            <select 
                                value={movementModal.motiu} 
                                onChange={e => setMovementModal(m => ({...m, motiu: e.target.value}))} 
                                className="px-3 py-2 border rounded bg-transparent"
                            >
                                {MOTIUS.map(m => (
                                    <option key={m} value={m}>{m}</option>
                                ))}
                            </select>

                            <label className="text-xs">Usuari</label>
                            <input 
                                value={movementModal.user} 
                                onChange={e => setMovementModal(m => ({...m, user: e.target.value}))} 
                                className="px-3 py-2 border rounded bg-transparent" 
                            />

                            <div className="flex gap-2 justify-end mt-3">
                                <button 
                                    onClick={() => setMovementModal({ 
                                        open: false, 
                                        itemId: null, 
                                        delta: 0, 
                                        type: 'Entrada', 
                                        motiu: MOTIUS[0], 
                                        user: 'Administrador' 
                                    })} 
                                    className="px-3 py-2 rounded border hover:bg-gray-50 dark:hover:bg-gray-700 transition"
                                >
                                    Cancel·lar
                                </button>
                                <button 
                                    onClick={commitMovement} 
                                    className="px-3 py-2 rounded bg-indigo-600 text-white hover:bg-indigo-700 transition"
                                >
                                    Guardar moviment
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {/* Modal d'historial i gestió d'eines */}
            {historyModal.open && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
                    <div className="bg-white dark:bg-gray-800 rounded-lg p-4 w-full max-w-lg">
                        <div className="flex items-center justify-between mb-3">
                            <h3 className="font-semibold">
                                {historyModal.isToolbox ? 'Gestió d\'Eines' : 'Historial de Moviments'}
                            </h3>
                            <button 
                                onClick={() => setHistoryModal({ open: false, itemId: null })} 
                                className="text-sm text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 transition"
                            >
                                Tancar
                            </button>
                        </div>
                        
                        {historyModal.isToolbox ? (
                            <div className="space-y-4">
                                {/* Llista d'eines actuals */}
                                <div className="border rounded-lg p-3">
                                    <h4 className="text-sm font-medium mb-2">Eines Actuals</h4>
                                    <div className="space-y-2">
                                        {historyModal.tools.length === 0 ? (
                                            <p className="text-sm text-gray-500">No hi ha eines registrades</p>
                                        ) : (
                                            historyModal.tools.map((eina, idx) => (
                                                <div key={idx} className="flex items-center justify-between gap-2 text-sm">
                                                    <span>{eina.nom}</span>
                                                    <div className="flex items-center gap-2">
                                                        <span className="px-2 py-1 bg-gray-100 dark:bg-gray-700 rounded">
                                                            {eina.disponible} disponibles
                                                        </span>
                                                        <button
                                                            onClick={() => {
                                                                const qty = parseInt(prompt(`Quantes eines de "${eina.nom}" vols retirar?`, "1"))
                                                                if (qty && qty > 0 && qty <= eina.disponible) {
                                                                    const motiu = prompt("Motiu de la retirada:", "")
                                                                    const user = prompt("Qui ho retira?:", "")
                                                                    if (motiu && user) {
                                                                        setItems(prev => prev.map(x => 
                                                                            x.id === historyModal.itemId 
                                                                                ? {
                                                                                    ...x,
                                                                                    eines: x.eines.map((e, i) => 
                                                                                        i === idx 
                                                                                            ? {...e, disponible: e.disponible - qty}
                                                                                            : e
                                                                                    ).filter(e => e.disponible > 0)
                                                                                }
                                                                                : x
                                                                        ))
                                                                        addMovement(
                                                                            historyModal.itemId,
                                                                            'Retirada',
                                                                            -qty,
                                                                            `Retirada de ${qty}x ${eina.nom} - ${motiu}`,
                                                                            user
                                                                        )
                                                                    }
                                                                }
                                                            }}
                                                            className="px-2 py-1 text-red-600 border border-red-200 rounded hover:bg-red-50 dark:hover:bg-red-900/20"
                                                        >
                                                            Retirar
                                                        </button>
                                                    </div>
                                                </div>
                                            ))
                                        )}
                                    </div>
                                </div>

                                {/* Formulari per afegir nova eina */}
                                <div className="border rounded-lg p-3">
                                    <h4 className="text-sm font-medium mb-2">Afegir Nova Eina</h4>
                                    <div className="grid gap-2">
                                        <input 
                                            type="text"
                                            placeholder="Nom de l'eina"
                                            className="w-full px-3 py-2 border rounded bg-transparent"
                                            onKeyDown={(e) => {
                                                if (e.key === 'Enter') {
                                                    const nom = e.target.value.trim()
                                                    if (nom) {
                                                        const qty = parseInt(prompt("Quantitat a afegir:", "1"))
                                                        if (qty && qty > 0) {
                                                            const user = prompt("Qui ho afegeix?:", "")
                                                            if (user) {
                                                                setItems(prev => prev.map(x => 
                                                                    x.id === historyModal.itemId 
                                                                        ? {
                                                                            ...x,
                                                                            eines: [
                                                                                ...x.eines,
                                                                                {nom, disponible: qty}
                                                                            ]
                                                                        }
                                                                        : x
                                                                ))
                                                                addMovement(
                                                                    historyModal.itemId,
                                                                    'Entrada',
                                                                    qty,
                                                                    `Afegides ${qty}x ${nom}`,
                                                                    user
                                                                )
                                                                e.target.value = ''
                                                            }
                                                        }
                                                    }
                                                }
                                            }}
                                        />
                                        <p className="text-xs text-gray-500">
                                            Prem Enter per afegir una nova eina
                                        </p>
                                    </div>
                                </div>

                                {/* Historial de moviments específic d'eines */}
                                <div className="border rounded-lg p-3">
                                    <h4 className="text-sm font-medium mb-2">Historial de Moviments</h4>
                                    <div className="max-h-40 overflow-auto">
                                        <ul className="space-y-2">
                                            {getMovimentsFor(historyModal.itemId)
                                                .filter(m => m.motiu.includes('eina'))
                                                .map(m => (
                                                    <li key={m.id} className="text-sm">
                                                        <div>
                                                            <strong>{m.tipus}</strong>
                                                            {m.quantitat > 0 ? ` (+${m.quantitat})` : ` (${m.quantitat})`}
                                                        </div>
                                                        <div className="text-xs text-gray-500">
                                                            {new Date(m.when).toLocaleString()} — {m.motiu} —{' '}
                                                            <em>{m.user}</em>
                                                        </div>
                                                    </li>
                                                ))
                                            }
                                        </ul>
                                    </div>
                                </div>
                            </div>
                        ) : (
                            <div className="max-h-80 overflow-auto">
                                {getMovimentsFor(historyModal.itemId).length === 0 ? (
                                    <div className="text-sm text-gray-500">
                                        No hi ha moviments registrats.
                                    </div>
                                ) : (
                                    <ul className="space-y-2">
                                        {getMovimentsFor(historyModal.itemId).map(m => (
                                            <li key={m.id} className="p-2 border rounded">
                                                <div className="text-sm">
                                                    <strong>{m.tipus}</strong> 
                                                    {m.quantitat > 0 ? ` (+${m.quantitat})` : ` ${m.quantitat}`}
                                                </div>
                                                <div className="text-xs text-gray-500">
                                                    {new Date(m.when).toLocaleString()} — {m.motiu} — 
                                                    <em>{m.user}</em>
                                                </div>
                                            </li>
                                        ))}
                                    </ul>
                                )}
                            </div>
                        )}
                    </div>
                </div>
            )}
        </div>
    )
}