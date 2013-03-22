worker_processes 3
timeout 30
preload_app true

Rainbows! do
  use :EventMachine
  worker_connections 100
end
