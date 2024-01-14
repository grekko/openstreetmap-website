FactoryBot.define do
  factory :note do
    latitude { 1 * GeoRecord::SCALE }
    longitude { 1 * GeoRecord::SCALE }
    body { "This is the open-comment" }
    # tile { QuadTile.tile_for_point(1,1) }
  end
end
