require "pagy/extras/overflow"
require "pagy/extras/array"

Pagy::DEFAULT[:items] = 30
Pagy::DEFAULT[:size] = 7
Pagy::DEFAULT[:overflow] = :last_page
