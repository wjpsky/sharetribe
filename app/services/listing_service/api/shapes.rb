module ListingService::API
  ShapeStore = ListingService::Store::Shape

  class Shapes

    def get(community_id:, listing_shape_id: nil, include_categories: false)
      if listing_shape_id
        find_opts = {
          community_id: community_id,
          listing_shape_id: listing_shape_id,
          include_categories: include_categories
        }

        Maybe(ShapeStore.get(find_opts)).map { |shape|
          Result::Success.new(shape)
        }.or_else {
          Result::Error.new("Can not find listing shape for #{find_opts}")
        }
      else
        Result::Success.new(ShapeStore.get_all(community_id: community_id, include_categories: include_categories))
      end

    end

    def create(community_id:, opts:)
      Result::Success.new(ShapeStore.create(
        community_id: community_id,
        opts: opts
      ))
    end

    def update(community_id:, listing_shape_id: nil, opts:)
      find_opts = {
        community_id: community_id,
        listing_shape_id: listing_shape_id
      }

      Maybe(ShapeStore.update(find_opts.merge(opts: opts))).map { |shape|
        Result::Success.new(shape)
      }.or_else {
        Result::Error.new("Can not find listing shape for #{find_opts}")
      }
    end

    def delete(community_id:, listing_shape_id:)
      find_opts = {
        community_id: community_id,
        listing_shape_id: listing_shape_id
      }

      Maybe(ShapeStore.delete(find_opts)).map { |shape|
        Result::Success.new(shape)
      }.or_else {
        Result::Error.new("Can not find listing shape for #{find_opts}")
      }
    end

  end
end
