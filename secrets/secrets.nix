let
  root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDBPInsE39S5AvT4XDsK6S+rj2xDtS38XicR6mYGBA2u";
  daniel = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJbyBsOYlK6k6hQvpOwe9v6xC0mqpUvaR7oRUjsKU7EZ";
  users = [ root daniel ];

  ovh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ1NzhcajOjzM2ldgT3iwRCGtGuBAO+j1+DOmo5HSaUh";
  systems = [ ovh ];
in
{
  "nextcloud-admin-pass.age".publicKeys = users ++ systems;
}