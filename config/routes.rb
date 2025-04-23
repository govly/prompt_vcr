PromptVcr::Engine.routes.draw do
  root to: 'cassettes#index'
  
  resources :cassettes, only: [:index, :show]
end
