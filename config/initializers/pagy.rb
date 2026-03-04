require "pagy/extras/overflow"

Pagy::DEFAULT[:items] = 30
Pagy::DEFAULT[:size] = 7
Pagy::DEFAULT[:overflow] = :last_page
