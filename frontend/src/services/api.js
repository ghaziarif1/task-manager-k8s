// frontend/src/services/api.js
import axios from 'axios';

// URL de base de l'API - en production le frontend utilise la route relative `/api` via Nginx proxy_pass
const API_BASE_URL = import.meta.env.VITE_BACKEND_API_URL || (import.meta.env.MODE === 'development' ? 'http://localhost:4040' : '/api');

// Créer une instance axios avec la configuration de base
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 10000, // 10 secondes timeout
});

// Intercepteur pour les réponses
api.interceptors.response.use(
  (response) => response,
  (error) => {
    console.error('API Error:', error);
    return Promise.reject(error);
  }
);

// Fonctions API pour les tâches
export const taskAPI = {
  // Récupérer toutes les tâches
  getAll: async () => {
    const response = await api.get('/tasks');
    return response.data;
  },

  // Créer une nouvelle tâche
  create: async (task) => {
    const response = await api.post('/tasks', task);
    return response.data;
  },

  // Mettre à jour une tâche
  update: async (id, task) => {
    const response = await api.put(`/tasks/${id}`, task);
    return response.data;
  },

  // Supprimer une tâche
  delete: async (id) => {
    const response = await api.delete(`/tasks/${id}`);
    return response.data;
  },

  // Vérifier la santé du backend
  health: async () => {
    const response = await axios.get(
      import.meta.env.MODE === 'development' ? 'http://localhost:4040/health' : '/health'
    );
    return response.data;
  }
};

export default api;