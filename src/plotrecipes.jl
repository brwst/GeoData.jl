using DimensionalData: refdims_title

struct GeoPlot end

# We only look at arrays with Lat/Lon here.
# Otherwise they fall back to DimensionalData.jl recipes
@recipe function f(A::AbstractGeoArray)
    A = GeoArray(A)
    if all(hasdim(A, (Lat(), Lon())))
        # Heatmap or multiple heatmaps. Use GD recipes.
        GeoPlot(), prepare(A)
    else
        # This is not a Lat/Lon heatmap. Fall back to DD recipes after reprojecting
        da = A |> GeoArray |> a -> DimArray(a; dims=maybe_reproject(dims(a)))
        DimensionalData.DimensionalPlot(), da
    end
end

# Plot 3d arrays as multiple tiled plots
@recipe function f(::GeoPlot, A::GeoArray{T,3,<:Tuple{<:Lat,<:Lon,D}}) where {T,D}
    nplots = size(A, 3)
    if nplots > 1
        :layout --> nplots
        :xguide --> permutedims(string.(val(dims(A, D))))
        for i in 1:nplots
            @series begin
                seriestype := :heatmap
                aspect_ratio := 1
                subplot := i
                slice = A[:, :, i]
                lats, lons = map(preparedim, dims(slice))
                lons, lats, parent(slice)
            end
        end
    else
        GeoPlot(), A[:, :, 1]
    end
end

# # Permute for correct Lat/Lon order
@recipe function f(::GeoPlot, A::GeoArray{T,3}) where {T}
    GeoPlot(), permutedims(A, (Lat, Lon, Dimension))
end

# # Plot a sinlge 2d map
@recipe function f(::GeoPlot, A::GeoArray{T,2,<:Tuple{<:Lat,<:Lon}}) where T
    :seriestype --> :heatmap
    :aspect_ratio --> 1
    :colorbar_title --> name(A)
    :title --> refdims_title(A)
    lats, lons = map(preparedim, dims(A))
    lons, lats, parent(A)
end

# # Permute for correct Lat/Lon order
@recipe function f(::GeoPlot, A::GeoArray{T,2,<:Tuple{<:Lon,<:Lat}}) where T
    GeoPlot(), permutedims(A)
end

# Plots heatmaps pixels are centered. 
# So we should center, and use the projected value.
# Except GDAL will wrap values that are shifted around 180, and break
# plotting. Not sure of a robust way to fix this - so just ploting
# as is for now. The error is only visible on very small arrays.
preparedim(d) = userval(d) # shiftindexloci(Center(), d) |> userval

# Convert arrays to a consistent missing value and Forward array order
prepare(A) = A |> maybereplace_missing |> forwardorder

maybereplace_missing(A::AbstractArray{<:AbstractFloat}) = replace_missing(A, NaN)
maybereplace_missing(A) = A
