module API
  class Files < Grape::API
    helpers do
      def commit_params(attrs)
        {
          file_path: attrs[:file_path],
          start_branch: attrs[:branch],
          branch_name: attrs[:branch],
          commit_message: attrs[:commit_message],
          file_content: attrs[:content],
          file_content_encoding: attrs[:encoding],
          author_email: attrs[:author_email],
          author_name: attrs[:author_name],
          last_commit_sha: attrs[:last_commit_id]
        }
      end

      def assign_file_vars!
        authorize! :download_code, user_project

        @commit = user_project.commit(params[:ref])
        not_found!('Commit') unless @commit

        @repo = user_project.repository
        @blob = @repo.blob_at(@commit.sha, params[:file_path])

        not_found!('File') unless @blob
        @blob.load_all_data!
      end

      def commit_response(attrs)
        {
          file_path: attrs[:file_path],
          branch: attrs[:branch]
        }
      end

      params :simple_file_params do
        requires :file_path, type: String, desc: 'The url encoded path to the file. Ex. lib%2Fclass%2Erb'
        requires :branch, type: String, desc: 'The name of branch'
        requires :commit_message, type: String, desc: 'Commit Message'
        optional :author_email, type: String, desc: 'The email of the author'
        optional :author_name, type: String, desc: 'The name of the author'
      end

      params :extended_file_params do
        use :simple_file_params
        requires :content, type: String, desc: 'File content'
        optional :encoding, type: String, values: %w[base64], desc: 'File encoding'
        optional :last_commit_id, type: String, desc: 'Last known commit id for this file'
      end
    end

    params do
      requires :id, type: String, desc: 'The project ID'
    end
    resource :projects, requirements: { id: %r{[^/]+} } do
      desc 'Get raw file contents from the repository'
      params do
        requires :file_path, type: String, desc: 'The url encoded path to the file. Ex. lib%2Fclass%2Erb'
        requires :ref, type: String, desc: 'The name of branch, tag commit'
      end
      get ":id/repository/files/:file_path/raw" do
        assign_file_vars!

        send_git_blob @repo, @blob
      end

      desc 'Get a file from the repository'
      params do
        requires :file_path, type: String, desc: 'The url encoded path to the file. Ex. lib%2Fclass%2Erb'
        requires :ref, type: String, desc: 'The name of branch, tag or commit'
      end
      get ":id/repository/files/:file_path", requirements: { file_path: /.+/ } do
        assign_file_vars!

        {
          file_name: @blob.name,
          file_path: @blob.path,
          size: @blob.size,
          encoding: "base64",
          content: Base64.strict_encode64(@blob.data),
          ref: params[:ref],
          blob_id: @blob.id,
          commit_id: @commit.id,
          last_commit_id: @repo.last_commit_id_for_path(@commit.sha, params[:file_path])
        }
      end

      desc 'Create new file in repository'
      params do
        use :extended_file_params
      end
      post ":id/repository/files/:file_path", requirements: { file_path: /.+/ } do
        authorize! :push_code, user_project

        file_params = declared_params(include_missing: false)
        result = ::Files::CreateService.new(user_project, current_user, commit_params(file_params)).execute

        if result[:status] == :success
          status(201)
          commit_response(file_params)
        else
          render_api_error!(result[:message], 400)
        end
      end

      desc 'Update existing file in repository'
      params do
        use :extended_file_params
      end
      put ":id/repository/files/:file_path", requirements: { file_path: /.+/ } do
        authorize! :push_code, user_project

        file_params = declared_params(include_missing: false)

        begin
          result = ::Files::UpdateService.new(user_project, current_user, commit_params(file_params)).execute
        rescue ::Files::UpdateService::FileChangedError => e
          render_api_error!(e.message, 400)
        end

        if result[:status] == :success
          status(200)
          commit_response(file_params)
        else
          http_status = result[:http_status] || 400
          render_api_error!(result[:message], http_status)
        end
      end

      desc 'Delete an existing file in repository'
      params do
        use :simple_file_params
      end
      delete ":id/repository/files/:file_path", requirements: { file_path: /.+/ } do
        authorize! :push_code, user_project

        file_params = declared_params(include_missing: false)
        result = ::Files::DeleteService.new(user_project, current_user, commit_params(file_params)).execute

        if result[:status] != :success
          render_api_error!(result[:message], 400)
        end
      end
    end
  end
end
