require 'shellwords'

class ExecutionsController < ApplicationController

	skip_before_filter :verify_authenticity_token

	def create
		execution_description = nil

		if not params[:hook].blank?
			hooks_dir = 'project/hooks'
			hook_name = params[:hook]+(params[:format] ? "." : "")+params[:format]
			hooks = Dir.glob("#{hooks_dir}/*")
			raise 'Incorrect hook request !' if (hook_name.include?("/") or !hooks.any? {|h| File.basename(h) == hook_name })
			hook = [hooks_dir,Shellwords.escape(hook_name)].join('/')
			Bundler.with_clean_env {
				IO.popen(hook, "w+") {|ls_io|
					ls_io.write(JSON.dump(params.to_hash))
					ls_io.close_write
					execution_description = JSON.load(ls_io.read)
				}
			}
		else
			execution_description = params[:execution].to_unsafe_h
		end

		execution = Execution.create_with_tasks(execution_description)
		summary = Execution.detailed_summary(include: ["task","task_details","task_artifacts","artifacts","tags"], conditions: "executions.id = ?", params: [execution.id]).first.description
		render json: summary
	end


	def show
		execution = Execution.find(params[:id])
		summary = Execution.detailed_summary(include: ["task","task_details","task_artifacts","artifacts","tags","task_tags"], conditions: "executions.id = ?", params: [execution.id]).first.description
		respond_to { |format|
			format.json { render json: summary }
		}
	end


	def duplicate
		execution_id = params[:id]
		original_execution = Execution.find(execution_id)
		duplicate_execution = original_execution.duplicate_with_tasks
		render json: duplicate_execution
	end

end
