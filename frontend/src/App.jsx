// frontend/src/App.jsx
import { useState, useEffect } from 'react'
import { taskAPI } from './services/api'
import './index.css'

export default function App() {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(false)
  const [backendStatus, setBackendStatus] = useState('checking')
  const [editingId, setEditingId] = useState(null)
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    status: 'pending',
    due_date: '',
  })

  // Vérifier la connexion au backend
  useEffect(() => {
    const checkBackendConnection = async () => {
      try {
        await taskAPI.health();
        setBackendStatus('connected');
      } catch (error) {
        console.error('Backend connection failed:', error);
        setBackendStatus('disconnected');
      }
    };
    checkBackendConnection();
  }, []);

  // Récupérer les tâches
  const fetchTasks = async () => {
    try {
      setLoading(true)
      const data = await taskAPI.getAll()
      setTasks(data)
    } catch (error) {
      console.error('Erreur lors du chargement:', error)
      alert('Erreur : Impossible de charger les tâches')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchTasks()
  }, [])

  // Gérer les changements du formulaire
  const handleChange = (e) => {
    const { name, value } = e.target
    setFormData((prev) => ({ ...prev, [name]: value }))
  }

  // Ajouter ou modifier une tâche
  const handleSubmit = async (e) => {
    e.preventDefault()

    if (!formData.title.trim()) {
      alert('Le titre est requis')
      return
    }

    try {
      if (editingId) {
        // Modifier
        await taskAPI.update(editingId, formData)
        setEditingId(null)
      } else {
        // Créer
        await taskAPI.create(formData)
      }

      setFormData({ title: '', description: '', status: 'pending', due_date: '' })
      await fetchTasks()
    } catch (error) {
      console.error('Erreur lors de la soumission:', error)
      alert('Erreur : Impossible de soumettre le formulaire')
    }
  }

  // Supprimer une tâche
  const handleDelete = async (id) => {
    if (window.confirm('Êtes-vous sûr de vouloir supprimer cette tâche ?')) {
      try {
        await taskAPI.delete(id)
        await fetchTasks()
      } catch (error) {
        console.error('Erreur lors de la suppression:', error)
        alert('Erreur : Impossible de supprimer la tâche')
      }
    }
  }

  // Éditer une tâche
  const handleEdit = (task) => {
    setFormData({
      title: task.title,
      description: task.description || '',
      status: task.status,
      due_date: task.due_date ? task.due_date.split('T')[0] : '',
    })
    setEditingId(task.id)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  // Annuler l'édition
  const handleCancel = () => {
    setFormData({ title: '', description: '', status: 'pending', due_date: '' })
    setEditingId(null)
  }

  const getStatusColor = (status) => {
    const colors = {
      pending: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
      completed: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
      in_progress: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
    }
    return colors[status] || colors.pending
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-slate-900 dark:to-slate-800 p-4 md:p-8">
      <div className="max-w-4xl mx-auto">
        {/* En-tête */}
        <div className="text-center mb-12 fade-in">
          <h1 className="text-4xl md:text-5xl font-bold text-slate-900 dark:text-white mb-2">
            📋 Task Manager
          </h1>
        </div>

        {/* Formulaire */}
        <form
          onSubmit={handleSubmit}
          className="bg-white dark:bg-slate-800 rounded-2xl shadow-xl p-8 mb-8 border-2 border-blue-200 dark:border-blue-900"
        >
          <h2 className="text-2xl font-bold text-slate-900 dark:text-white mb-6">
            {editingId ? '✏️ Modifier la tâche' : '➕ Ajouter une tâche'}
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Titre */}
            <input
              type="text"
              name="title"
              placeholder="Titre de la tâche"
              value={formData.title}
              onChange={handleChange}
              className="col-span-1 md:col-span-2 px-4 py-3 border-2 border-slate-300 dark:border-slate-600 rounded-lg focus:outline-none focus:border-blue-500 dark:bg-slate-700 dark:text-white"
            />

            {/* Description */}
            <textarea
              name="description"
              placeholder="Description"
              value={formData.description}
              onChange={handleChange}
              rows="3"
              className="col-span-1 md:col-span-2 px-4 py-3 border-2 border-slate-300 dark:border-slate-600 rounded-lg focus:outline-none focus:border-blue-500 dark:bg-slate-700 dark:text-white resize-none"
            />

            {/* Statut */}
            <select
              name="status"
              value={formData.status}
              onChange={handleChange}
              className="px-4 py-3 border-2 border-slate-300 dark:border-slate-600 rounded-lg focus:outline-none focus:border-blue-500 dark:bg-slate-700 dark:text-white"
            >
              <option value="pending">Pending</option>
              <option value="in_progress">En cours</option>
              <option value="completed">Complétée</option>
            </select>

            {/* Date d'échéance */}
            <input
              type="date"
              name="due_date"
              value={formData.due_date}
              onChange={handleChange}
              className="px-4 py-3 border-2 border-slate-300 dark:border-slate-600 rounded-lg focus:outline-none focus:border-blue-500 dark:bg-slate-700 dark:text-white"
            />
          </div>

          {/* Boutons */}
          <div className="flex gap-4 mt-8">
            <button
              type="submit"
              className="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 rounded-lg transition duration-200 transform hover:scale-105"
            >
              {editingId ? '💾 Sauvegarder' : '➕ Ajouter'}
            </button>
            {editingId && (
              <button
                type="button"
                onClick={handleCancel}
                className="flex-1 bg-slate-400 hover:bg-slate-500 text-white font-bold py-3 rounded-lg transition duration-200"
              >
                ❌ Annuler
              </button>
            )}
          </div>
        </form>

        {/* Liste des tâches */}
        <div>
          <h2 className="text-2xl font-bold text-slate-900 dark:text-white mb-6">
            📝 Mes tâches ({tasks.length})
          </h2>

          {loading ? (
            <div className="text-center py-12">
              <p className="text-slate-600 dark:text-slate-300">⏳ Chargement...</p>
            </div>
          ) : tasks.length === 0 ? (
            <div className="bg-white dark:bg-slate-800 rounded-2xl p-12 text-center shadow-lg">
              <p className="text-xl text-slate-500 dark:text-slate-400">
                Aucune tâche. Crée-en une pour commencer ! 🚀
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {tasks.map((task) => (
                <div
                  key={task.id}
                  className="task-card bg-white dark:bg-slate-800 rounded-xl shadow-lg p-6 border-l-4 border-blue-500 hover:shadow-xl transition duration-200"
                >
                  <h3 className="text-lg font-bold text-slate-900 dark:text-white mb-2 line-clamp-2">
                    {task.title}
                  </h3>

                  <p className="text-sm text-slate-600 dark:text-slate-400 mb-4 line-clamp-3">
                    {task.description || 'Pas de description'}
                  </p>

                  <div className="mb-4">
                    <span className={`inline-block px-3 py-1 rounded-full text-sm font-semibold ${getStatusColor(task.status)}`}>
                      {task.status}
                    </span>
                  </div>

                  {task.due_date && (
                    <p className="text-xs text-slate-500 dark:text-slate-400 mb-4">
                      📅 {new Date(task.due_date).toLocaleDateString('fr-FR')}
                    </p>
                  )}

                  <div className="flex gap-3">
                    <button
                      onClick={() => handleEdit(task)}
                      className="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 rounded-lg transition duration-200 text-sm"
                    >
                      ✏️ Modifier
                    </button>
                    <button
                      onClick={() => handleDelete(task.id)}
                      className="flex-1 bg-red-600 hover:bg-red-700 text-white font-semibold py-2 rounded-lg transition duration-200 text-sm"
                    >
                      🗑️ Supprimer
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}