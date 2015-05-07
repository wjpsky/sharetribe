class Admin::ListingShapesController < ApplicationController
  before_filter :ensure_is_admin

  ensure_feature_enabled :shape_ui

  before_filter :ensure_no_braintree_or_checkout

  LISTING_SHAPES_NAVI_LINK = "listing_shapes"

  Shape = ListingShapeDataTypes::Shape

  def index
    category_count = @current_community.categories.count
    template_label_key_list = ListingShapeTemplates.new(process_summary).label_key_list

    render("index",
           locals: {
             selected_left_navi_link: LISTING_SHAPES_NAVI_LINK,
             templates: template_label_key_list,
             category_count: category_count,
             listing_shapes: all_shapes(community_id: @current_community.id, include_categories: true)})
  end

  def new
    template = ListingShapeTemplates.new(process_summary).find(params[:template], available_locales.map(&:second))

    unless template
      return redirect_to action: :index
    end

    render_new_form(template, process_summary, available_locales())
  end

  def edit
    shape = ShapeService.new(processes).get(
      community_id: @current_community.id,
      listing_shape_id: params[:id],
      locales: available_locales.map { |_, locale| locale }
    ).data

    return redirect_to error_not_found_path if shape.nil?

    count = Listing.where(listing_shape_id: params[:id]).currently_open.count()

    render_edit_form(params[:id], shape, count, process_summary, available_locales())
  end

  def create
    shape = filter_uneditable_fields(FormViewLayer.params_to_shape(params), process_summary)

    create_result = validate_shape(shape).and_then { |shape|
      ShapeService.new(processes).create(
        community_id: @current_community.id,
        default_locale: @current_community.default_locale,
        opts: shape
      )
    }

    if create_result.success
      flash[:notice] = t("admin.listing_shapes.new.create_success", shape: pick_translation(shape[:name]))
      redirect_to action: :index
    else
      flash[:error] = t("admin.listing_shapes.new.create_failure", error_msg: create_result.error_msg)
      render_new_form(shape, process_summary, available_locales())
    end

  end

  def update
    shape = filter_uneditable_fields(FormViewLayer.params_to_shape(params), process_summary)

    update_result = validate_shape(shape).and_then { |shape|
      ShapeService.new(processes).update(
        community_id: @current_community.id,
        listing_shape_id: params[:id],
        opts: shape
      )
    }

    if update_result.success
      flash[:notice] = t("admin.listing_shapes.edit.update_success", shape: pick_translation(shape[:name]))
      return redirect_to admin_listing_shapes_path
    else
      flash[:error] = t("admin.listing_shapes.edit.update_failure", error_msg: update_result.error_msg)
      render_edit_form(params[:id], shape, process_summary, available_locales())
    end
  end

  def order
    ordered_ids = params[:order].map(&:to_i)

    shapes = all_shapes(community_id: @current_community.id, include_categories: false)

    old_shape_order_id_map = shapes.map { |s|
      {
        id: s[:id],
        sort_priority: s[:sort_priority]
      }
    }

    old_shape_order = old_shape_order_id_map.map { |s| s[:sort_priority] }

    distinguisable_order = old_shape_order.reduce([old_shape_order.first]) { |memo, x|
      last = memo.last
      if x <= last
        memo << last + 1
      else
        memo << x
      end
    }

    new_shape_order_id_map = ordered_ids.zip(distinguisable_order).map { |id, sort|
      {
        id: id,
        sort_priority: sort
      }
    }

    diff = ArrayUtils.diff_by_key(old_shape_order_id_map, new_shape_order_id_map, :id)

    diff.select { |d| d[:action] == :changed }.each { |d|
      opts = { sort_priority: d[:value][:sort_priority]}
      listing_api.shapes.update(community_id: @current_community.id, listing_shape_id: d[:value][:id], opts: opts)
    }

    render nothing: true, status: 200
  end

  def close_listings
    shape_res = listing_api.shapes.get(community_id: @current_community.id, listing_shape_id: params[:id])

    if shape_res.success
      Listing.where(listing_shape_id: params[:id]).update_all(open: false)
      flash[:notice] = "Successfully closed listings"
      return redirect_to action: :edit, id: params[:id]
    else
      flash[:error] = "Can not find listing shape with id #{params[:id]}"
      return redirect_to action: :index
    end
  end

  def destroy
    shape_res = listing_api.shapes.get(community_id: @current_community.id, listing_shape_id: params[:id])

    if shape_res.success
      Listing.where(listing_shape_id: params[:id]).update_all(open: false, listing_shape_id: nil)
      # TODO Delete listing shape
      flash[:notice] = "Successfully deleted order type #{t(shape_res.data[:name_tr_key])}"
    else
      flash[:error] = "Can not find listing shape with id #{params[:id]}"
    end

    redirect_to action: :index
  end

  private

  def filter_uneditable_fields(shape, process_summary)
    uneditable_keys = uneditable_fields(process_summary).select { |_, uneditable| uneditable }.keys
    shape.except(*uneditable_keys)
  end

  def uneditable_fields(process_summary)
    {
      shipping_enabled: !process_summary[:preauthorize_available],
      online_payments: !process_summary[:preauthorize_available]
    }
  end

  def render_new_form(form, process_summary, available_locs)
    locals = common_locals(form, 0, process_summary, available_locs)
    render("new", locals: locals)
  end

  def render_edit_form(id, form, count, process_summary, available_locs)
    locals = common_locals(form, count, process_summary, available_locs).merge(
      id: id,
      name: pick_translation(form[:name])
    )
    render("edit", locals: locals)
  end

  def common_locals(form, count, process_summary, available_locs)
    { selected_left_navi_link: LISTING_SHAPES_NAVI_LINK,
      uneditable_fields: uneditable_fields(process_summary),
      shape: FormViewLayer.shape_to_locals(form),
      count: count,
      locale_name_mapping: available_locs.map { |name, l| [l, name] }.to_h
    }
  end

  def listing_api
    ListingService::API::Api
  end

  def all_shapes(community_id:, include_categories:)
    listing_api.shapes.get(community_id: community_id, include_categories: include_categories)
      .maybe()
      .or_else([])
  end

  def process_summary
    @process_summary ||= processes.reduce({}) { |info, process|
      info[:preauthorize_available] = true if process[:process] == :preauthorize
      info
    }
  end

  def processes
    @processes ||= TransactionService::API::Api.processes.get(community_id: @current_community.id)[:data]
  end

  def validate_shape(form)
    form = Shape.call(form)

    errors = []

    if form[:shipping_enabled] && !form[:online_payments]
      errors << "Shipping can not be enabled without online payments"
    end

    if form[:online_payments] && !form[:price_enabled]
      errors << "Online payments can not be enabled without price"
    end

    if form[:units].present? && !form[:price_enabled]
      errors << "Price units can not be used without price field"
    end

    if errors.empty?
      Result::Success.new(form)
    else
      Result::Error.new(errors.join(", "))
    end
  end

  def pick_translation(translations)
    translations.find { |(locale, translation)|
      locale.to_s == I18n.locale.to_s
    }.second
  end

  def ensure_no_braintree_or_checkout
    gw = PaymentGateway.where(community_id: @current_community.id).first
    if gw
      flash[:error] = "Not available for your payment gateway: #{gw.type}"
      redirect_to edit_details_admin_community_path(@current_community.id)
    end
  end

  # FormViewLayer provides helper functions to transform:
  # - Shape hash to renderable format
  # - params from form back to Shape
  #
  module FormViewLayer
    module_function

    def params_to_shape(params)
      form_params = HashUtils.symbolize_keys(params)
      with_units = form_params.merge(
        units: parse_units(form_params[:units])
      )

      Shape.call(with_units)
    end

    def shape_to_locals(shape)
      shape = Shape.call(shape)

      shape.merge(
        units: expand_units(shape[:units]),
      )
    end

    # private

    # Take units from shape and add predefined units
    def expand_units(shape_units)
      shape_units_set = shape_units.map { |t| t[:type] }.to_set

      ListingShapeHelper.predefined_unit_types
        .map { |t| {type: t, enabled: shape_units_set.include?(t), label: I18n.t("admin.listing_shapes.units.#{t}")} }
        .concat(shape_units
                 .select { |unit| unit[:type] == :custom }
                 .map { |unit| {type: unit[:type], enabled: true, label: translate(unit[:translation_key])} }) # TODO Change translate
    end

    def parse_units(selected_units)
      (selected_units || []).map { |type, _| {type: type.to_sym, enabled: true}}
    end
  end
end
