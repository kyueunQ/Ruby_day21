Rails.application.routes.draw do
  resources :chat_rooms do
    member do
      # chat_room/:id/join 으로 왔을 때 메소드 실행
      post '/join' => 'chat_rooms#user_admit_room', as: 'join'
    end
  end
  
  devise_for :users
  
  root 'chat_rooms#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
